# Bibliothèques hébergées avec l'app (pour le hors ligne)

Copiées telles quelles depuis leur source publique, pour que l'app démarre sans réseau.

| Fichier | Version | Source | Licence |
|---|---|---|---|
| `supabase.js` | @supabase/supabase-js 2.119.2 | https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js | MIT |
| `katex/` (js, css, 20 polices woff2) | KaTeX 0.16.11 | https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.16.11/ | MIT |

Mise à jour : remplacer les fichiers, puis changer le numéro de `CACHE` dans `sw.js` (`flashplai-shell-vN`) pour que les appareils les rechargent.
Ces bibliothèques ne sont pas couvertes par la licence PLAI du dépôt : elles gardent la leur.
