-- FlashFWB — Migration v3 (à exécuter dans Supabase > SQL Editor)
-- Correctif sécurité : RLS student_progress restreint aux codes actifs

-- Avant : for all using (true) with check (true) → écriture ouverte à tous
-- Après : lecture/écriture limitées aux lignes dont le code_id référence un code actif

drop policy if exists "Eleve : sa progression" on public.student_progress;

create policy "Eleve : sa progression" on public.student_progress
  for all using (
    exists (select 1 from public.class_codes where id = student_progress.code_id and active = true)
  )
  with check (
    exists (select 1 from public.class_codes where id = student_progress.code_id and active = true)
  );
