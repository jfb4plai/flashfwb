# FlashFWB v5.1 — Guide d'installation

Application de cartes mémoire pédagogiques pour les enseignants FWB.

---

## Étape 1 — Créer un projet Supabase

1. Va sur https://supabase.com et crée un compte (gratuit)
2. Clique **New project**
3. Donne un nom au projet, ex : `flashfwb`
4. Choisis une région proche : **West EU (Ireland)** recommandé
5. Génère un mot de passe fort pour la base de données
6. Attends 2 minutes que le projet se crée

---

## Étape 2 — Récupérer tes clés Supabase

1. Dans ton projet Supabase, va dans **Project Settings > API**
2. Copie **Project URL** (ex : `https://abcdefgh.supabase.co`)
3. Copie **anon public key** (la clé longue sous "Project API keys")

---

## Étape 3 — Configurer l'app

Ouvre le fichier `config.js` et remplace les deux valeurs :

```js
const SUPABASE_URL = 'https://abcdefgh.supabase.co';   // ta Project URL
const SUPABASE_ANON_KEY = 'eyJhbGci...';               // ta anon key
```

---

## Étape 4 — Créer la base de données

1. Dans Supabase, va dans **SQL Editor**
2. Clique **New query**
3. Copie-colle tout le contenu du fichier `setup.sql`
4. Clique **Run**
5. Tu dois voir "Success. No rows returned"

---

## Étape 5 — Activer la confirmation d'email (optionnel)

Par défaut Supabase demande de confirmer l'email à l'inscription.
Pour désactiver (plus simple en test) :
- **Authentication > Providers > Email**
- Décoche **Confirm email**
- Sauvegarde

---

## Étape 6 — Mettre le projet sur GitHub

1. Va sur https://github.com/new
2. Crée un repo public nommé `flashfwb`
3. Sur ton ordinateur, ouvre un terminal dans le dossier du projet
4. Exécute :

```bash
git init
git add .
git commit -m "FlashFWB v5.1"
git branch -M main
git remote add origin https://github.com/jfb4plai/flashfwb.git
git push -u origin main
```

---

## Étape 7 — Déployer sur Vercel

1. Va sur https://vercel.com et connecte-toi avec GitHub
2. Clique **Add New > Project**
3. Sélectionne le repo `flashfwb`
4. Laisse tous les paramètres par défaut
5. Clique **Deploy**
6. En 1 minute, ton app est en ligne sur une URL type `flashfwb.vercel.app`

---

## Structure des fichiers

```
flashfwb/
├── index.html      Application complète
├── config.js       Clés Supabase (à remplir)
├── vercel.json     Configuration du déploiement
├── setup.sql       Script base de données
└── README.md       Ce fichier
```

---

## Fonctionnalités v5.1

- Inscription / connexion enseignant (email + mot de passe)
- Paquets sauvegardés dans le cloud (accessible depuis n'importe quel appareil)
- Images et sons stockés dans la base de données
- Toutes les fonctionnalités v4 : TTS bilingue, Leitner, import Markdown, générateur Claude

## Prochaines versions

- v5.2 : Code de classe + accès élèves + partage avec médias
- v5.3 : Tableau de bord progression
- v5.4 : Mode hors-ligne (PWA)

---

## Problèmes fréquents

**"Invalid API key"** → Vérifie que config.js contient les bonnes valeurs Supabase

**"Email not confirmed"** → Confirme l'email reçu, ou désactive la confirmation (étape 5)

**Les cartes ne se chargent pas** → Vérifie que le SQL a bien été exécuté (étape 4)
