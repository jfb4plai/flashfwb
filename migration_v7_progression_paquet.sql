-- FlashPLAI — Migration v7 (à exécuter dans Supabase > SQL Editor)
-- Objet : la progression des élèves suit la vie du paquet.
--   A. Quand une carte est supprimée, sa progression est supprimée avec elle (plus de « 7/6 » dans les résultats).
--      Nettoie aussi les lignes orphelines déjà présentes.
--   B. Fonction « remettre à zéro la progression de certaines cartes », appelée par l'app quand l'enseignant
--      coche des cartes dont le sens a changé. Réservée au propriétaire du paquet.
-- Sûr à relancer. Ne retire aucun accès existant. Aucune nouvelle table : pas de GRANT de table.
-- Préfixe « flash_ » : le projet Supabase est partagé entre plusieurs apps.
--
-- Contrôle AVANT exécution (facultatif) : nombre de lignes orphelines qui seront supprimées.
--   select count(*) from public.student_progress p
--   where not exists (select 1 from public.cards c where c.id = p.card_id);
--
-- Ordre conseillé : exécuter ce script, puis publier la nouvelle version de l'app.
-- L'app publiée avant le script fonctionne (elle prévient seulement que la remise à zéro n'a pas pu se faire).

begin;

-- ===== A. Nettoyage automatique =====

create or replace function public.flash_cards_cleanup_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.student_progress where card_id = old.id;
  return old;
end;
$$;

revoke all on function public.flash_cards_cleanup_progress() from public, anon, authenticated;

drop trigger if exists flash_cards_cleanup_progress on public.cards;
create trigger flash_cards_cleanup_progress
  after delete on public.cards
  for each row execute function public.flash_cards_cleanup_progress();

-- Lignes orphelines déjà présentes (cartes supprimées avant cette migration)
delete from public.student_progress p
where not exists (select 1 from public.cards c where c.id = p.card_id);

-- ===== B. Remise à zéro choisie par l'enseignant =====
-- Supprimer la ligne d'un élève pour une carte = la carte repart en boîte 1 pour lui.
-- Renvoie le nombre de lignes supprimées ; 0 si le paquet n'appartient pas à l'appelant.
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
  delete from public.student_progress
  where deck_id = p_deck_id and card_id = any(p_card_ids);
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.flash_reset_card_progress(uuid, uuid[]) from public, anon;
grant execute on function public.flash_reset_card_progress(uuid, uuid[]) to authenticated;

commit;

-- Contrôles APRÈS exécution :
--   1. select count(*) from public.student_progress p where not exists (select 1 from public.cards c where c.id = p.card_id);  -- 0
--   2. select tgname from pg_trigger where tgname = 'flash_cards_cleanup_progress';                                             -- 1 ligne
--   3. select public.flash_reset_card_progress(gen_random_uuid(), array[gen_random_uuid()]);                                    -- 0 (pas connecté)
