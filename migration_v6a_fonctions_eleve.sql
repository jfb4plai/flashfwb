-- FlashPLAI — Migration v6a (à exécuter dans Supabase > SQL Editor)
-- ÉTAPE 1/2 : crée deux fonctions pour le parcours élève.
-- Ne retire AUCUN accès existant : l'ancienne version de l'app continue de fonctionner.
-- Sûr à relancer (create or replace).
--
-- Pourquoi : aujourd'hui, la clé publique de l'app permet de lire sans connexion les tables
-- class_codes, student_progress (prénoms des élèves), decks et cards.
-- Avec ces fonctions, l'élève ne peut plus rien lire que ce que son code de classe lui donne,
-- et l'étape v6b retirera ensuite l'accès direct aux tables.
--
-- Ordre à respecter :
--   1. exécuter CE script (v6a) ;
--   2. publier la nouvelle version de l'app (elle appelle ces fonctions) ;
--   3. vérifier un parcours élève réel ;
--   4. exécuter migration_v6b_retrait_acces_direct.sql.
--
-- Préfixe « flash_ » : le projet Supabase est partagé entre plusieurs apps.
-- Aucune nouvelle table : pas de GRANT de table à ajouter.

-- Lecture : un code valide (actif, non expiré) renvoie le paquet, ses cartes et la progression
-- de CET élève uniquement. Un code invalide renvoie null (aucune indication sur la raison).
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
           'weighted_review', d.weighted_review, 'spaced', d.spaced)
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

-- Écriture : enregistre la boîte d'UNE carte pour UN élève, seulement si le code est valide et
-- si la carte appartient bien au paquet du code. Limite à 200 élèves distincts par code.
create or replace function public.flash_student_save(
  p_code text, p_name text, p_card_id uuid, p_box integer, p_last_seen timestamptz)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code public.class_codes%rowtype;
  v_name text;
begin
  v_name := left(trim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), 30);
  if v_name = '' or p_code is null or p_card_id is null or p_box is null or p_box not between 1 and 3 then
    return false;
  end if;

  select * into v_code
  from public.class_codes
  where code = upper(trim(p_code))
    and active = true
    and (expires_at is null or expires_at > now());
  if not found then
    return false;
  end if;

  if not exists (select 1 from public.cards where id = p_card_id and deck_id = v_code.deck_id) then
    return false;
  end if;

  if not exists (select 1 from public.student_progress
                 where code_id = v_code.id and student_name = v_name)
     and (select count(distinct student_name) from public.student_progress
          where code_id = v_code.id) >= 200 then
    return false;
  end if;

  insert into public.student_progress (code_id, deck_id, student_name, card_id, box, last_seen, updated_at)
  values (v_code.id, v_code.deck_id, v_name, p_card_id, p_box, coalesce(p_last_seen, now()), now())
  on conflict (code_id, student_name, card_id)
  do update set box = excluded.box, last_seen = excluded.last_seen, updated_at = now();

  return true;
end;
$$;

revoke all on function public.flash_student_open(text, text) from public;
revoke all on function public.flash_student_save(text, text, uuid, integer, timestamptz) from public;
grant execute on function public.flash_student_open(text, text) to anon, authenticated;
grant execute on function public.flash_student_save(text, text, uuid, integer, timestamptz) to anon, authenticated;

-- Contrôle rapide (doit renvoyer null et false : code inexistant) :
--   select public.flash_student_open('ZZZZ-0000', 'Test');
--   select public.flash_student_save('ZZZZ-0000', 'Test', gen_random_uuid(), 1, now());
