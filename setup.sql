-- FlashFWB v5.1 — Script SQL à exécuter dans Supabase > SQL Editor

-- Table des paquets
create table public.decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  lang_q text not null default 'fr-BE',
  lang_a text not null default 'fr-BE',
  tts text not null default 'a',
  created_at timestamptz not null default now()
);

-- Table des cartes
create table public.cards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid references public.decks on delete cascade not null,
  question text not null,
  answer text not null,
  q_img text,
  a_img text,
  q_aud text,
  a_aud text,
  box integer not null default 1,
  last_seen timestamptz,
  position integer not null default 0
);

-- Sécurité : chaque enseignant ne voit que ses paquets
alter table public.decks enable row level security;
create policy "Enseignant : ses paquets" on public.decks
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Sécurité : chaque enseignant ne voit que ses cartes
alter table public.cards enable row level security;
create policy "Enseignant : ses cartes" on public.cards
  for all using (
    exists (
      select 1 from public.decks
      where decks.id = cards.deck_id
        and decks.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.decks
      where decks.id = cards.deck_id
        and decks.user_id = auth.uid()
    )
  );

-- Index pour les performances
create index on public.cards (deck_id);
create index on public.decks (user_id);
