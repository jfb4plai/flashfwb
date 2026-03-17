# FlashFWB v5.4

Application de cartes mémoire pédagogiques pour les enseignants de la Fédération Wallonie-Bruxelles.

**URL de l'app :** https://flashfwb-cd2m.vercel.app

---

## Fonctionnalités

- Comptes enseignants — paquets sauvegardés dans le cloud
- Création de cartes : saisie manuelle, import Markdown, import CSV, générateur Claude
- Images : upload, URL externe, pictogrammes ARASAAC (FR + EN)
- Audio : enregistrement micro + synthèse vocale TTS bilingue
- Ordre des cartes : Leitner (par boîte) ou aléatoire
- Code de classe + QR code — accès élèves sans compte
- Tableau de bord enseignant — progression par élève, cartes difficiles
- Mode sombre supporté

---

## Structure des fichiers

```
flashfwb/
├── index.html        Application complète (v5.4)
├── plai-logo.jpg     Logo PLAI affiché dans l'interface
├── vercel.json       Configuration du déploiement Vercel
├── setup.sql         Script SQL initial (v5.1)
├── setup_v52.sql     Migration v5.2 — codes de classe + progression élèves
├── setup_v53.sql     Migration v5.3 — ordre aléatoire
└── README.md         Ce fichier
```

> **Note :** Les clés Supabase sont intégrées directement dans `index.html`.
> `config.js` n'est plus utilisé depuis la v5.4.

---

## Installation from scratch

### 1. Créer un projet Supabase

1. Va sur https://supabase.com — crée un compte gratuit
2. Clique **New project** — région recommandée : **West EU (Ireland)**
3. Note le mot de passe généré pour la base de données

### 2. Configurer les clés dans index.html

En haut du fichier `index.html`, remplace :

```js
const SUPABASE_URL = 'https://TON-PROJET.supabase.co';
const SUPABASE_ANON_KEY = 'ta-cle-anonyme';
```

Les clés se trouvent dans Supabase → **Project Settings → API**.

### 3. Exécuter les scripts SQL

Dans Supabase → **SQL Editor → New query**, exécute les scripts dans cet ordre :

1. `setup.sql` — tables principales (decks, cards)
2. `setup_v52.sql` — codes de classe + progression élèves
3. `setup_v53.sql` — colonne shuffle

Résultat attendu à chaque fois : `Success. No rows returned`

### 4. Désactiver la confirmation email (recommandé)

Supabase → **Authentication → Sign In / Providers → Email** → décoche **Confirm email** → Sauvegarde.

### 5. Configurer l'URL de redirection

Supabase → **Authentication → URL Configuration** :
- Site URL : `https://flashfwb-cd2m.vercel.app`
- Redirect URLs : ajoute `https://flashfwb-cd2m.vercel.app/**`

### 6. Déployer sur Vercel

1. Uploade tous les fichiers sur GitHub (repo public)
2. Va sur https://vercel.com → connecte-toi avec GitHub
3. **Add New Project** → sélectionne le repo → **Deploy**
4. L'app est en ligne en 1 minute

---

## Mises à jour

Pour mettre à jour l'app après une modification :

1. Remplace le(s) fichier(s) modifié(s) sur GitHub
2. Vercel redéploie automatiquement en ~1 minute

---

## Problèmes fréquents

**Connexion tourne en rond** → Les extensions TTS du navigateur peuvent bloquer Supabase. Le nettoyage automatique du cache est intégré au chargement de l'app. Si le problème persiste, ouvrir en navigation privée.

**"Email not confirmed"** → Désactive la confirmation email dans Supabase (étape 4)

**Les cartes ne se chargent pas** → Vérifie que les 3 scripts SQL ont bien été exécutés

**Le logo PLAI n'apparaît pas** → Vérifie que `plai-logo.jpg` est bien présent dans le repo GitHub

---

## Roadmap

- v5.5 : Mode hors-ligne (PWA) + export PDF des paquets
