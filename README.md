# FlashPLAI v5.4

Application de cartes mémoire pédagogiques pour les enseignants de la Fédération Wallonie-Bruxelles, proposée aux écoles coopérantes du Pôle de la Ville de Liège (PLAI). Anciennement nommée FlashFWB.

**URL de l'app :** https://flashfwb.vercel.app

---

## Fonctionnalités

- Comptes enseignants — paquets sauvegardés dans le cloud
- Création de cartes : saisie manuelle, import Markdown, import CSV, générateur Claude
- Hors ligne (élève) : l'app démarre sans réseau (Supabase et KaTeX hébergés dans `vendor/`, service worker v2) ; à la première entrée en ligne, copie du paquet dans IndexedDB ; réponses mises en file sur l'appareil et envoyées à la reconnexion (la plus récente gagne, délai de grâce de 7 jours après expiration du code, garde contre une remise à zéro de l'enseignant) ; bouton « Préparer pour le hors ligne » (images distantes, formules, taille) ; bandeau d'état ; date de dernière synchronisation dans les résultats. La première entrée avec un code doit se faire en ligne. Tests : `node tests/offline.test.js`
- Import CSV : lecteur complet (guillemets doublés, cellules multilignes, séparateur , ; ou tabulation, UTF-8 ou ANSI Excel) ; modèle Excel et CSV dans `modeles/`, téléchargeables depuis l'onglet Importer > CSV
- Import intelligent (Markdown, CSV) : une question déjà présente (casse et ponctuation finale ignorées) met à jour la réponse de la carte existante au lieu de créer un doublon, donc la progression des élèves est conservée ; les autres cartes sont ajoutées
- Images : upload, URL externe, pictogrammes ARASAAC (FR + EN)
- Audio : enregistrement micro + synthèse vocale TTS bilingue
- Ordre des cartes : Leitner (par boîte) ou aléatoire
- Code de classe + QR code — accès élèves sans compte
- Tableau de bord enseignant — progression par élève, cartes difficiles
- Identifiant élève : prénom (sans nom de famille) ou code élève fourni par l'enseignant (liste imprimable depuis le code de classe)
- Mode « Lecture facilitée » (Arial, interligne et espacement agrandis), mémorisé sur l'appareil
- Option par paquet « Espacer les révisions dans le temps » (ordre Leitner) : nécessite `migration_v4.sql`
- Tableau de bord en deux onglets : « Élèves » et « Cartes difficiles » (au moins la moitié des élèves la laissent en boîte « À revoir »)
- Tableau de bord : une ligne compacte par élève (barre de progression, compteurs, date), à déplier pour voir la liste des cartes à revoir et « presque »
- Générateur IA : niveau, nombre de cartes et contexte de classe dans le prompt ; cartes importées à relire avant sauvegarde
- Accueil à deux entrées (« Je suis enseignant·e » / « Je suis élève »), le lien QR ouvre directement le formulaire élève
- Application installable (PWA) : manifeste, icônes et service worker qui met en cache la coquille de l'app. Sans réseau, l'écran s'ouvre mais les paquets et la progression (Supabase) ne se chargent pas
- Impression des cartes recto-verso (bouton « Imprimer les cartes » de l'éditeur) : 8 cartes par page A4, questions puis réponses, colonnes inversées au verso
- Profils élèves mémorisés sur l'appareil (8 maximum, effaçables) : un clic remplit prénom/code ; stockés dans le navigateur de l'appareil seulement
- Durée de validité du code de classe (sans limite, 1 semaine, 1 mois, fin d'année scolaire) : nécessite `migration_v5.sql` ; le même code peut être prolongé
- Formules mathématiques : bouton « ∑ Formule » sur chaque carte, éditeur visuel (MathLive, clavier mathématique, aucune syntaxe à connaître) ; stockées en LaTeX entre `$…$` dans le texte, rendues par KaTeX à l'étude, dans le tableau de bord et à l'impression. Bibliothèques chargées à la demande depuis un CDN : sans réseau, les formules s'affichent en texte brut. Le signe `$` est réservé aux formules (écrire les prix avec €). La voix de synthèse dit « formule »
- Cartes repliables : au-delà de 8 cartes, l'éditeur les affiche repliées (question, réponse, ⚠ si incomplète, ● si image ou audio) ; « Tout replier / Tout déplier » ; une carte ajoutée s'ouvre
- Éditeur de paquet en onglets : Cartes, Réglages (langues, voix, ordre, Leitner, espacement), Importer (Markdown, CSV, Claude), Partager (code de classe et QR, résultats, impression) ; barre Sauvegarder / Réviser toujours visible en bas
- Mode sombre supporté

---

## Structure des fichiers

```
flashfwb/
├── index.html        Application complète (v5.4)
├── plai-logo.jpg     Logo PLAI affiché dans l'interface
├── manifest.webmanifest, sw.js, icon-192.png, icon-512.png   Installation (PWA)
├── vercel.json       Configuration du déploiement Vercel
├── setup.sql         Script SQL initial (v5.1) : tables decks et cards
├── migration_v2.sql  Migration v2 : colonnes Leitner, codes de classe, progression élèves
├── migration_v3.sql  Migration v3 : correctif de sécurité (RLS de student_progress)
├── migration_v6a_fonctions_eleve.sql, migration_v6b_retrait_acces_direct.sql   Migration v6 : accès élève par fonctions
├── migration_v8_synchro_hors_ligne.sql   Migration v8 : synchronisation hors ligne, délai de grâce, garde de remise à zéro
├── offline-core.js, tests/offline.test.js   Logique pure du hors ligne et ses tests
├── vendor/   Supabase et KaTeX hébergés (voir vendor/README.md)
├── migration_v7_progression_paquet.sql   Migration v7 : progression suit la vie du paquet
├── migration_v5.sql  Migration v5 : expiration des codes de classe
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
5. `migration_v5.sql` — expiration des codes de classe (colonne `class_codes.expires_at` + deux politiques élèves recréées ; facultatif : sans elle, l'option est masquée)
6. `migration_v6a_fonctions_eleve.sql` puis `migration_v6b_retrait_acces_direct.sql` — sécurité : l'élève passe par deux fonctions serveur (`flash_student_open`, `flash_student_save`) et les visiteurs non connectés n'ont plus aucun accès direct aux tables. v6a d'abord, puis publier l'app, puis v6b. Obligatoire : l'app actuelle ne fonctionne plus côté élève sans v6a
7. `migration_v7_progression_paquet.sql` — progression des élèves : supprime la progression d'une carte quand la carte est supprimée (et nettoie les lignes orphelines) ; crée `flash_reset_card_progress`, appelée quand l'enseignant coche, à l'enregistrement, des cartes dont le sens a changé. Sans v7, l'app fonctionne mais la remise à zéro est refusée (message d'avertissement)
8. `migration_v8_synchro_hors_ligne.sql` — synchronisation des réponses faites hors ligne (`flash_student_sync`), délai de grâce de 7 jours après expiration du code, date de remise à zéro par carte (`cards.progress_reset_at`). À exécuter AVANT de publier la nouvelle app ; sans v8, l'app retombe sur l'envoi carte par carte (sans délai de grâce ni garde)

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
