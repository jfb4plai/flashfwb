-- FlashPLAI — Migration v4 (à exécuter dans Supabase > SQL Editor)
-- Ajoute l'option « Espacer les révisions dans le temps » sur chaque paquet.
-- Ajout de colonne seul, sans suppression. Sûr à relancer.
-- Les paquets existants gardent leur comportement actuel (valeur false).
-- Aucun nouveau GRANT nécessaire : la table decks existe déjà et ses droits ne changent pas.

alter table public.decks add column if not exists spaced boolean not null default false;
