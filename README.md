# FlashPLAI v5.4

Application de cartes mémoire pédagogiques pour les enseignants de la Fédération Wallonie-Bruxelles, proposée aux écoles coopérantes du Pôle de la Ville de Liège (PLAI). Anciennement nommée FlashFWB.

**URL de l'app :** https://flashfwb.vercel.app

---

## Fonctionnalités

- Comptes enseignants — paquets sauvegardés dans le cloud
- Création de cartes : saisie manuelle, import Markdown, import CSV, générateur Claude
- Images : upload, URL externe, pictogrammes ARASAAC (FR + EN)
- Audio : enregistrement micro + synthèse vocale TTS bilingue
- Ordre des cartes : Leitner (par boîte) ou aléatoire
- Code de classe + QR code — accès élèves sans compte
- Tableau de bord enseignant — progression par élève, cartes difficiles
- Identifiant élève : prénom (sans nom de famille) ou code élève fourni par l'enseignant (liste imprimable depuis le code de classe)
- Mode « Lecture facilitée » (Arial, interligne et espacement agrandis), mémorisé sur l'appareil
- Option par paquet « Espacer les révisions dans le temps » (ordre Leitner) : nécessite `migration_v4.sql`
- Tableau de bord : pour chaque élève, la liste des cartes à revoir et « presque »
- Générateur IA : niveau, nombre de cartes et contexte de classe dans le prompt ; cartes importées à relire avant sauvegarde
- Accueil à deux entrées (« Je suis enseignant·e » / « Je suis élève »), le lien QR ouvre directement le formulaire élève
- Mode sombre supporté

---

## Structure des fichiers

```
flashfwb/
├── index.html        Application complète (v5.4)
├── plai-logo.jpg     Logo PLAI affiché dans l'interface
├── vercel.json       Configuration du déploiement Vercel
├── setup.sql         Script SQL initial (v5.1) : tables decks et cards
├── migration_v2.sql  Migration v2 : colonnes Leitner, codes de classe, progression élèves
├── migration_v3.sql  Migration v3 : correctif de sécurité (RLS de student_progress)
├── migration_v4.sql  Migration v4 : option « espacer les révisions » (colonne decks.spaced)
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
2. `migration_v2.sql` — colonnes Leitner (ordre, sans saut de boîte, pondération), codes de classe, progression élèves
3. `migration_v3.sql` — correctif de sécurité : la progression élève n'est lisible et modifiable que pour un code de classe actif

4. `migration_v4.sql` — option « espacer les révisions » par paquet (ajout d'une colonne, facultatif : sans elle, l'option est masquée)

Les scripts v2, v3 et v4 sont relançables sans risque. Sur une base neuve, v2 contient déjà la règle de sécurité de v3 : v3 sert aux bases créées avant ce correctif.

Résultat attendu à chaque fois : `Success. No rows returned`

### 4. Désactiver la confirmation email (recommandé)

Supabase → **Authentication → Sign In / Providers → Email** → décoche **Confirm email** → Sauvegarde.

### 5. Configurer l'URL de redirection

Supabase → **Authentication → URL Configuration** :
- Site URL : `https://flashfwb.vercel.app`
- Redirect URLs : ajoute `https://flashfwb.vercel.app/**`

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

## Licences

- **Code** : [PolyForm Noncommercial 1.0.0](LICENSE). Usage non commercial uniquement.
- **Contenus pédagogiques** : [CC BY-NC-SA 4.0](LICENSE-CONTENT.md). Réutilisation et adaptation non commerciales, avec attribution et partage dans les mêmes conditions.
- **Logo et identité visuelle PLAI** : tous droits réservés (voir `LICENSE-CONTENT.md`).

Auteur : Jean-François Beguin, Référent numérique, https://jfb4plai.com
