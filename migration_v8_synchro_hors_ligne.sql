-- FlashPLAI — Migration v8 (à exécuter dans Supabase > SQL Editor)
-- Objet : synchronisation des réponses faites hors ligne.
--   1. cards.progress_reset_at : date de la dernière remise à zéro de la progression d'une carte (v7).
--      Une réponse faite AVANT cette date est refusée à la synchronisation : un appareil resté hors ligne
--      ne peut pas annuler une remise à zéro décidée par l'enseignant.
--   2. flash_reset_card_progress (remplace celle de v7) : pose cette date en plus de supprimer les lignes.
--   3. flash_student_sync : reçoit un lot de réponses d'UN élève, applique « la plus récente gagne »,
--      accepte encore les réponses jusqu'à 7 jours après l'expiration du code (délai de grâce),
--      puis renvoie le paquet et la progression à jour (même forme que flash_student_open).
-- Sûr à relancer. Ne retire aucun accès existant. flash_student_open et flash_student_save sont inchangées :
-- l'ancienne version de l'app continue de fonctionner. Aucune nouvelle table.
-- Préfixe « flash_ » : le projet Supabase est partagé entre plusieurs apps.
--
-- Ordre conseillé : exécuter ce script, puis publier la nouvelle version de l'app.
-- L'app publiée avant le script fonctionne (elle retombe sur flash_student_save, sans délai de grâce
-- ni garde contre la remise à zéro).

begin;

-- ===== 1. Date de remise à zéro par carte =====
alter table public.cards add column if not exists progress_reset_at timestamptz;

-- ===== 2. Remise à zéro : supprime les lignes ET date l'opération =====
create or replace function public.flash_reset_card_progress(p_deck_id uuid, p_card_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if auth.uid() is null or p_deck_id is null or p_card_ids is null then
    return 0;
  end if;
  if not exists (select 1 from public.decks where id = p_deck_id and user_id = auth.uid()) then
    return 0;
  end if;
  update public.cards set progress_reset_at = now()
  where deck_id = p_deck_id and id = any(p_card_ids);
  delete from public.student_progress
  where deck_id = p_deck_id and card_id = any(p_card_ids);
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.flash_reset_card_progress(uuid, uuid[]) from public, anon;
grant execute on function public.flash_reset_card_progress(uuid, uuid[]) to authenticated;

-- ===== 3. Synchronisation d'un lot de réponses =====
-- p_items : [{"card_id": "<uuid>", "box": 1..3, "last_seen": "<horodatage ISO>"}, ...] (500 maximum)
-- Renvoie {status: 'invalid' | 'expired' | 'full' | 'too_many'} sans rien écrire, ou
-- {status: 'ok', grace, accepted, rejected, server_time, code_id, code, student_name, deck, cards, progress}.
-- « rejected » = réponse plus ancienne que celle déjà enregistrée, antérieure à une remise à zéro,
-- ou carte qui n'appartient plus au paquet : le client peut la supprimer de sa file.
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
           'weighted_review', d.weighted_review, 'spaced', d.spaced)
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

revoke all on function public.flash_student_sync(text, text, jsonb) from public;
grant execute on function public.flash_student_sync(text, text, jsonb) to anon, authenticated;

commit;

-- Contrôles APRÈS exécution :
--   1. select public.flash_student_sync('ZZZZ-0000', 'Test', '[]'::jsonb);           -- {"status": "invalid"}
--   2. select column_name from information_schema.columns
--      where table_name = 'cards' and column_name = 'progress_reset_at';             -- 1 ligne
