-- FlashPLAI — Migration v6b (à exécuter dans Supabase > SQL Editor)
-- ÉTAPE 2/2 : retire l'accès direct aux tables pour les visiteurs non connectés.
--
-- À NE PAS EXÉCUTER avant que :
--   1. migration_v6a_fonctions_eleve.sql ait été exécutée ;
--   2. la nouvelle version de l'app (qui appelle les fonctions flash_student_*) soit publiée ;
--   3. un parcours élève réel ait été testé (entrer avec un code, répondre à une carte).
-- Après ce script, une ANCIENNE version de l'app (onglet resté ouvert, copie en cache) ne pourra
-- plus charger les cartes côté élève : recharger la page suffit.
--
-- Contrôle AVANT exécution (facultatif) : liste des politiques actuelles. Elle montre notamment
-- celle qui rend decks et cards lisibles sans connexion (absente de setup.sql, donc ajoutée à la main) :
--   select tablename, policyname, roles, cmd, qual
--   from pg_policies
--   where schemaname = 'public' and tablename in ('decks','cards','class_codes','student_progress')
--   order by tablename, policyname;
--
-- Ce que fait le script, dans une seule transaction (tout réussit ou rien ne change) :
--   - supprime TOUTES les politiques existantes de ces 4 tables, quel que soit leur nom ;
--   - recrée uniquement les politiques « enseignant » (chacun ne voit que ses données) ;
--   - retire à la clé publique (rôle anon) tout droit direct sur ces tables.
-- Les fonctions flash_student_* (security definer) restent le seul chemin pour les élèves.
-- L'intégration CorpusActif écrit dans decks et cards avec la clé « service » : non concernée par RLS.

begin;

alter table public.decks            enable row level security;
alter table public.cards            enable row level security;
alter table public.class_codes      enable row level security;
alter table public.student_progress enable row level security;

do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('decks', 'cards', 'class_codes', 'student_progress')
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Enseignant : ses paquets
create policy "Enseignant : ses paquets" on public.decks
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Enseignant : ses cartes
create policy "Enseignant : ses cartes" on public.cards
  for all using (
    exists (select 1 from public.decks where decks.id = cards.deck_id and decks.user_id = auth.uid())
  )
  with check (
    exists (select 1 from public.decks where decks.id = cards.deck_id and decks.user_id = auth.uid())
  );

-- Enseignant : ses codes de classe
create policy "Enseignant : ses codes" on public.class_codes
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Enseignant : lecture de la progression des élèves de ses codes
create policy "Enseignant : voir progression" on public.student_progress
  for select using (
    exists (
      select 1 from public.class_codes cc
      join public.decks d on d.id = cc.deck_id
      where cc.id = student_progress.code_id and d.user_id = auth.uid()
    )
  );

-- Plus aucun droit direct pour les visiteurs non connectés
revoke all on public.decks            from anon;
revoke all on public.cards            from anon;
revoke all on public.class_codes      from anon;
revoke all on public.student_progress from anon;

commit;

-- Contrôle APRÈS exécution : sans connexion, ces lectures doivent renvoyer 0 ligne ou une erreur,
-- et la liste ci-dessus ne doit plus contenir que les 4 politiques « Enseignant ».
