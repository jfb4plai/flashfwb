-- FlashPLAI — Migration v5 (à exécuter dans Supabase > SQL Editor)
-- Ajoute une date d'expiration facultative aux codes de classe.
-- Colonne ajoutée seule (null = pas d'expiration, comportement actuel conservé) ;
-- les deux politiques élèves sont recréées pour refuser un code expiré côté serveur.
-- L'enseignant garde l'accès à ses codes et à la progression (politiques enseignant inchangées).
-- Aucun nouveau GRANT : les tables existent déjà. Sûr à relancer.

alter table public.class_codes add column if not exists expires_at timestamptz;

drop policy if exists "Eleve : lire code actif" on public.class_codes;
create policy "Eleve : lire code actif" on public.class_codes
  for select using (active = true and (expires_at is null or expires_at > now()));

drop policy if exists "Eleve : sa progression" on public.student_progress;
create policy "Eleve : sa progression" on public.student_progress
  for all using (
    exists (select 1 from public.class_codes
            where id = student_progress.code_id and active = true
              and (expires_at is null or expires_at > now()))
  )
  with check (
    exists (select 1 from public.class_codes
            where id = student_progress.code_id and active = true
              and (expires_at is null or expires_at > now()))
  );
