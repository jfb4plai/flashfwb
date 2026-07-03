-- FlashFWB — Migration v2 (à exécuter dans Supabase > SQL Editor)
-- Sûr à relancer : utilise IF NOT EXISTS et ADD COLUMN IF NOT EXISTS

-- Colonnes Leitner ajoutées après la création initiale
alter table public.decks add column if not exists shuffle text not null default 'leitner';
alter table public.decks add column if not exists no_skip_box boolean not null default false;
alter table public.decks add column if not exists weighted_review boolean not null default false;

-- Table codes de classe (partage élèves via QR/code court)
create table if not exists public.class_codes (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid references public.decks on delete cascade not null,
  user_id uuid references auth.users on delete cascade not null,
  code text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.class_codes enable row level security;

drop policy if exists "Enseignant : ses codes" on public.class_codes;
create policy "Enseignant : ses codes" on public.class_codes
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Lecture publique pour que les élèves puissent valider un code
drop policy if exists "Eleve : lire code actif" on public.class_codes;
create policy "Eleve : lire code actif" on public.class_codes
  for select using (active = true);

-- Table progression élèves
create table if not exists public.student_progress (
  id uuid primary key default gen_random_uuid(),
  code_id uuid references public.class_codes on delete cascade not null,
  deck_id uuid not null,
  student_name text not null,
  card_id uuid not null,
  box integer not null default 1,
  last_seen timestamptz,
  updated_at timestamptz not null default now(),
  unique(code_id, student_name, card_id)
);

alter table public.student_progress enable row level security;

drop policy if exists "Enseignant : voir progression" on public.student_progress;
create policy "Enseignant : voir progression" on public.student_progress
  for select using (
    exists (
      select 1 from public.class_codes cc
      join public.decks d on d.id = cc.deck_id
      where cc.id = student_progress.code_id
        and d.user_id = auth.uid()
    )
  );

drop policy if exists "Eleve : sa progression" on public.student_progress;
create policy "Eleve : sa progression" on public.student_progress
  for all using (
    exists (select 1 from public.class_codes where id = student_progress.code_id and active = true)
  )
  with check (
    exists (select 1 from public.class_codes where id = student_progress.code_id and active = true)
  );

-- Index
create index if not exists idx_class_codes_deck on public.class_codes(deck_id);
create index if not exists idx_class_codes_code on public.class_codes(code);
create index if not exists idx_student_progress_code on public.student_progress(code_id);
