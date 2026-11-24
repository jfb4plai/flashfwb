-- FlashPLAI — Migration v9 (à exécuter dans Supabase > SQL Editor)
-- Délais de révision réglables par paquet (option « Espacer les révisions dans le temps ») :
--   gap2 = jours avant qu'une carte « Presque » (boîte 2) soit reproposée (défaut 1, valeurs actuelles de l'app)
--   gap3 = jours avant qu'une carte « Maîtrisé » (boîte 3) soit reproposée (défaut 3)
-- Les deux fonctions élève (flash_student_open, flash_student_sync) sont redéfinies À L'IDENTIQUE de v6a et v8,
-- avec seulement gap2 et gap3 ajoutés dans l'objet « deck » qu'elles renvoient.
-- Sûr à relancer. Ne retire aucun accès. Aucune nouvelle table : pas de GRANT de table à ajouter
-- (les nouvelles colonnes de public.decks suivent les droits existants de la table).
-- Sans cette migration, l'app fonctionne comme avant (délais fixes 1 et 3 jours, champs masqués).

alter table public.decks add column if not exists gap2 smallint not null default 1 check (gap2 between 1 and 365);
alter table public.decks add column if not exists gap3 smallint not null default 3 check (gap3 between 1 and 365);

create or replace function public.flash_student_open(p_code text, p_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code  public.class_codes%rowtype;
  v_name  text;
  v_known text;
  v_deck  jsonb;
  v_cards jsonb;
  v_prog  jsonb;
begin
  v_name := left(trim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), 30);
  if v_name = '' or p_code is null then
    return null;
  end if;

  select * into v_code
  from public.class_codes
  where code = upper(trim(p_code))
    and active = true
    and (expires_at is null or expires_at > now());
  if not found then
    return null;
  end if;

  -- Même identifiant écrit avec une autre casse (Sophie / sophie) : on reprend l'orthographe enregistrée
  select student_name into v_known
  from public.student_progress
  where code_id = v_code.id and lower(student_name) = lower(v_name)
  order by updated_at desc
  limit 1;
  v_name := coalesce(v_known, v_name);

  select jsonb_build_object(
           'id', d.id, 'name', d.name, 'lang_q', d.lang_q, 'lang_a', d.lang_a, 'tts', d.tts,
           'shuffle', d.shuffle, 'no_skip_box', d.no_skip_box,
           'weighted_review', d.weighted_review, 'spaced', d.spaced,
           'gap2', d.gap2, 'gap3', d.gap3)
    into v_deck
  from public.decks d
  where d.id = v_code.deck_id;

  -- Cartes : contenu seulement (pas la boîte ni la date de révision personnelles de l'enseignant)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'question', c.question, 'answer', c.answer,
           'q_img', c.q_img, 'a_img', c.a_img, 'q_aud', c.q_aud, 'a_aud', c.a_aud,
           'position', c.position) order by c.position), '[]'::jsonb)
    into v_cards
  from public.cards c
  where c.deck_id = v_code.deck_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'card_id', p.card_id, 'box', p.box, 'last_seen', p.last_seen)), '[]'::jsonb)
    into v_prog
  from public.student_progress p
  where p.code_id = v_code.id and p.student_name = v_name;

  return jsonb_build_object(
    'code_id', v_code.id,
    'code', v_code.code,
    'student_name', v_name,
    'deck', v_deck,
    'cards', v_cards,
    'progress', v_prog);
end;
$$;

create or replace function public.flash_student_sync(p_code text, p_name text, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code     public.class_codes%rowtype;
  v_name     text;
  v_known    text;
  v_item     jsonb;
  v_card     uuid;
  v_box      integer;
  v_seen     timestamptz;
  v_reset    timestamptz;
  v_n        integer;
  v_accepted integer := 0;
  v_rejected integer := 0;
  v_deck     jsonb;
  v_cards    jsonb;
  v_prog     jsonb;
begin
  v_name := left(trim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), 30);
  if v_name = '' or p_code is null then
    return jsonb_build_object('status', 'invalid');
  end if;

  -- Code désactivé par l'enseignant : refus. Code expiré : accepté pendant 7 jours (délai de grâce).
  select * into v_code
  from public.class_codes
  where code = upper(trim(p_code)) and active = true;
  if not found then
    return jsonb_build_object('status', 'invalid');
  end if;
  if v_code.expires_at is not null and v_code.expires_at + interval '7 days' <= now() then
    return jsonb_build_object('status', 'expired');
  end if;

  if p_items is not null and jsonb_typeof(p_items) = 'array' and jsonb_array_length(p_items) > 500 then
    return jsonb_build_object('status', 'too_many');
  end if;

  select student_name into v_known
  from public.student_progress
  where code_id = v_code.id and lower(student_name) = lower(v_name)
  order by updated_at desc
  limit 1;
  v_name := coalesce(v_known, v_name);

  if not exists (select 1 from public.student_progress where code_id = v_code.id and student_name = v_name)
     and (select count(distinct student_name) from public.student_progress
          where code_id = v_code.id) >= 200 then
    return jsonb_build_object('status', 'full');
  end if;

  if p_items is not null and jsonb_typeof(p_items) = 'array' then
    for v_item in select * from jsonb_array_elements(p_items) loop
      begin
        v_card := (v_item ->> 'card_id')::uuid;
        v_box  := (v_item ->> 'box')::integer;
        -- une horloge d'appareil en avance ne peut pas dépasser l'heure du serveur
        v_seen := least(coalesce((v_item ->> 'last_seen')::timestamptz, now()), now());
      exception when others then
        v_rejected := v_rejected + 1;
        continue;
      end;

      if v_box is null or v_box not between 1 and 3 then
        v_rejected := v_rejected + 1;
        continue;
      end if;

      select progress_reset_at into v_reset
      from public.cards where id = v_card and deck_id = v_code.deck_id;
      if not found then
        v_rejected := v_rejected + 1;   -- carte supprimée ou d'un autre paquet
        continue;
      end if;
      if v_reset is not null and v_seen <= v_reset then
        v_rejected := v_rejected + 1;   -- réponse antérieure à la remise à zéro de l'enseignant
        continue;
      end if;

      insert into public.student_progress (code_id, deck_id, student_name, card_id, box, last_seen, updated_at)
      values (v_code.id, v_code.deck_id, v_name, v_card, v_box, v_seen, now())
      on conflict (code_id, student_name, card_id)
      do update set box = excluded.box, last_seen = excluded.last_seen, updated_at = now()
      where public.student_progress.last_seen is null
         or public.student_progress.last_seen < excluded.last_seen;
      get diagnostics v_n = row_count;
      if v_n > 0 then v_accepted := v_accepted + 1; else v_rejected := v_rejected + 1; end if;
    end loop;
  end if;

  select jsonb_build_object(
           'id', d.id, 'name', d.name, 'lang_q', d.lang_q, 'lang_a', d.lang_a, 'tts', d.tts,
           'shuffle', d.shuffle, 'no_skip_box', d.no_skip_box,
           'weighted_review', d.weighted_review, 'spaced', d.spaced,
           'gap2', d.gap2, 'gap3', d.gap3)
    into v_deck
  from public.decks d
  where d.id = v_code.deck_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'question', c.question, 'answer', c.answer,
           'q_img', c.q_img, 'a_img', c.a_img, 'q_aud', c.q_aud, 'a_aud', c.a_aud,
           'position', c.position) order by c.position), '[]'::jsonb)
    into v_cards
  from public.cards c
  where c.deck_id = v_code.deck_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'card_id', p.card_id, 'box', p.box, 'last_seen', p.last_seen)), '[]'::jsonb)
    into v_prog
  from public.student_progress p
  where p.code_id = v_code.id and p.student_name = v_name;

  return jsonb_build_object(
    'status', 'ok',
    'grace', (v_code.expires_at is not null and v_code.expires_at <= now()),
    'accepted', v_accepted,
    'rejected', v_rejected,
    'server_time', now(),
    'code_id', v_code.id,
    'code', v_code.code,
    'student_name', v_name,
    'deck', v_deck,
    'cards', v_cards,
    'progress', v_prog);
end;
$$;

revoke all on function public.flash_student_open(text, text) from public;
grant execute on function public.flash_student_open(text, text) to anon, authenticated;

revoke all on function public.flash_student_sync(text, text, jsonb) from public;
grant execute on function public.flash_student_sync(text, text, jsonb) to anon, authenticated;
