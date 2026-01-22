# 📚 GUIDE COMPLET STRIPE CONNECT - FIATOPE
## Le guide ultime pour comprendre et gérer les paiements crowdfunding

---

# 🎯 TABLE DES MATIÈRES

1. [Introduction - C'est quoi tout ça ?](#1-introduction)
2. [Les acteurs du système](#2-les-acteurs)
3. [Le Dashboard Stripe - Votre centre de contrôle](#3-dashboard-stripe)
4. [L'interface Fiatope Admin](#4-interface-fiatope)
5. [Cycle de vie complet d'une campagne](#5-cycle-de-vie)
6. [Guide pas-à-pas: Créer et gérer un projet](#6-guide-projet)
7. [Guide pas-à-pas: Gérer les contributions](#7-guide-contributions)
8. [Guide pas-à-pas: Fin de campagne](#8-fin-campagne)
9. [Problèmes courants et solutions](#9-problemes)
10. [Commandes techniques (pour développeurs)](#10-commandes)
11. [Glossaire - Les mots expliqués](#11-glossaire)

---

# 1. INTRODUCTION - C'EST QUOI TOUT ÇA ? {#1-introduction}

## 1.1 Qu'est-ce que Fiatope ?

**Fiatope** est une plateforme de **crowdfunding** (financement participatif). 

**En termes simples:** C'est un site web où:
- Des **porteurs de projet** présentent leurs idées
- Des **contributeurs** donnent de l'argent pour soutenir ces projets
- **Fiatope** (vous!) gère tout ça et prend une petite commission

## 1.2 Qu'est-ce que Stripe ?

**Stripe** est le service qui gère l'argent. C'est comme une banque en ligne spécialisée pour les sites web.

**Ce que fait Stripe pour nous:**
- ✅ Accepter les cartes bancaires des contributeurs
- ✅ Garder l'argent en sécurité
- ✅ Envoyer l'argent aux porteurs de projet
- ✅ Gérer les remboursements si nécessaire

## 1.3 Qu'est-ce que Stripe Connect ?

**Stripe Connect** est une fonctionnalité spéciale de Stripe qui permet:
- De créer un "compte Stripe" pour chaque porteur de projet
- De transférer l'argent directement vers le compte bancaire du porteur
- De prélever automatiquement la commission Fiatope

**Imaginez:** Stripe Connect est comme un grand coffre-fort avec des compartiments séparés pour chaque porteur de projet.

## 1.4 Comment l'argent circule ?

```
CONTRIBUTEUR                    FIATOPE (Stripe)                 PORTEUR
     |                               |                              |
     |  1. Paye 100€ par carte      |                              |
     |----------------------------->|                              |
     |                               |                              |
     |                    2. Stripe prend ~3.4€ de frais           |
     |                               |                              |
     |                    3. Reste 96.60€ chez Fiatope             |
     |                               |                              |
     |                    4. À la fin de la campagne:              |
     |                               |                              |
     |                    5. Fiatope prend 5% = 5€ commission      |
     |                               |                              |
     |                               |  6. Transfert 95€ au porteur |
     |                               |----------------------------->|
     |                               |                              |
```

## 1.5 Les montants en détail

Pour une contribution de **100€**, voici ce qui se passe:

| Étape | Description | Montant |
|-------|-------------|---------|
| 1 | Le contributeur paye | 100.00€ |
| 2 | Stripe prend ses frais (~3.4% + 0.25€) | -3.65€ |
| 3 | Fiatope reçoit | 96.35€ |
| 4 | Commission Fiatope (5% de 100€) | 5.00€ |
| 5 | Montant transféré au porteur (100€ - 5€) | 95.00€ |
| 6 | **Commission nette Fiatope** (5€ - 3.65€) | **1.35€** |

---

# 2. LES ACTEURS DU SYSTÈME {#2-les-acteurs}

## 2.1 Le Contributeur (celui qui donne de l'argent)

**Qui c'est ?** Une personne qui veut soutenir un projet.

**Ce qu'il fait:**
1. Va sur Fiatope
2. Choisit un projet qu'il aime
3. Clique sur "Contribuer"
4. Entre le montant (ex: 50€)
5. Paye avec sa carte bancaire
6. Reçoit un email de confirmation

**Ce qu'il voit:**
- La page du projet avec la description
- Le bouton "Contribuer"
- Un formulaire de paiement sécurisé (fourni par Stripe)
- Une confirmation de paiement

## 2.2 Le Porteur de Projet (celui qui reçoit l'argent)

**Qui c'est ?** Une personne ou organisation qui a une idée et cherche du financement.

**Ce qu'il fait:**
1. Crée un compte sur Fiatope
2. Crée son projet (description, photos, objectif financier)
3. **Complète son profil Stripe** (étape importante!)
4. Lance sa campagne
5. Fait la promotion de son projet
6. Reçoit l'argent à la fin (si la campagne réussit)

**Ce qu'il doit fournir à Stripe:**
- Son nom complet
- Sa date de naissance
- Son adresse
- Son numéro de téléphone
- Une pièce d'identité (carte d'identité ou passeport)
- Son IBAN (numéro de compte bancaire)

## 2.3 L'Administrateur Fiatope (VOUS!)

**Qui c'est ?** La personne qui gère la plateforme Fiatope.

**Ce que vous faites:**
1. Validez les nouveaux projets
2. Activez Stripe pour les projets
3. Surveillez les paiements
4. Aidez les porteurs en difficulté
5. Gérez les remboursements si nécessaire
6. Suivez les revenus de Fiatope

---

# 3. LE DASHBOARD STRIPE - VOTRE CENTRE DE CONTRÔLE {#3-dashboard-stripe}

## 3.1 Comment accéder au Dashboard Stripe

1. **Ouvrez votre navigateur** (Chrome, Firefox, Safari...)
2. **Allez sur:** https://dashboard.stripe.com
3. **Connectez-vous** avec vos identifiants Stripe Fiatope

## 3.2 La page d'accueil du Dashboard

Quand vous vous connectez, vous voyez:

```
┌─────────────────────────────────────────────────────────────────┐
│  STRIPE                                              [Recherche]│
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📊 Solde disponible: 1,234.56 €                               │
│  📈 Solde en attente: 567.89 €                                 │
│                                                                 │
│  [Graphique des revenus des derniers jours]                    │
│                                                                 │
│  Paiements récents:                                            │
│  • 150.00 € - Pierre Dupont - il y a 2 heures                  │
│  • 50.00 € - Marie Martin - il y a 5 heures                    │
│  • 200.00 € - Jean Durant - hier                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Ce que signifie chaque élément:**
- **Solde disponible:** Argent que vous pouvez utiliser maintenant
- **Solde en attente:** Argent reçu mais pas encore disponible (délai de 2-7 jours)
- **Paiements récents:** Les dernières contributions reçues

## 3.3 Le menu de gauche (Navigation)

Voici les sections importantes:

```
📊 Accueil
💳 Paiements          ← Voir toutes les contributions
💸 Solde              ← Voir l'argent disponible
🔄 Clients            ← Voir les contributeurs
🏢 Connect            ← Voir les porteurs de projet (TRÈS IMPORTANT!)
⚙️ Paramètres         ← Configuration du compte
```

## 3.4 Section PAIEMENTS - Voir les contributions

**Pour y accéder:** Cliquez sur "Paiements" dans le menu de gauche.

**Ce que vous voyez:**

```
┌─────────────────────────────────────────────────────────────────┐
│  PAIEMENTS                                                      │
├─────────────────────────────────────────────────────────────────┤
│  [Tous] [Réussis] [Remboursés] [Échoués]    [Filtrer] [Exporter]│
├─────────────────────────────────────────────────────────────────┤
│  MONTANT     CLIENT           DESCRIPTION     DATE      STATUT  │
├─────────────────────────────────────────────────────────────────┤
│  150,00 €   pierre@mail.com  Contribution    18 jan    ✅ Réussi│
│   50,00 €   marie@mail.com   Contribution    18 jan    ✅ Réussi│
│   75,00 €   jean@mail.com    Contribution    17 jan    🔄 Remb. │
│   25,00 €   paul@mail.com    Contribution    17 jan    ❌ Échoué│
└─────────────────────────────────────────────────────────────────┘
```

### 3.4.1 Les filtres de paiement

**Cliquez sur "Filtrer" pour voir les options:**

| Filtre | Ce qu'il fait | Quand l'utiliser |
|--------|---------------|------------------|
| Date | Voir une période précise | "Montrez-moi les paiements de janvier" |
| Montant | Filtrer par somme | "Montrez-moi les gros paiements (+100€)" |
| Statut | Réussi/Échoué/Remboursé | "Montrez-moi les paiements échoués" |
| Client | Par email du payeur | "Trouvez les paiements de marie@mail.com" |

**Comment utiliser les filtres:**
1. Cliquez sur "Filtrer"
2. Choisissez votre critère (ex: "Statut")
3. Sélectionnez la valeur (ex: "Échoué")
4. Les résultats se mettent à jour automatiquement
5. Pour enlever le filtre, cliquez sur la croix (×) à côté du filtre

### 3.4.2 Voir les détails d'un paiement

**Cliquez sur n'importe quel paiement** pour voir ses détails:

```
┌─────────────────────────────────────────────────────────────────┐
│  PAIEMENT pi_3Sr1uXGU9iw1wSnA1yIl7aGc                          │
├─────────────────────────────────────────────────────────────────┤
│  Montant: 150,00 €                                              │
│  Statut: ✅ Réussi                                              │
│  Date: 18 janvier 2026 à 14:32                                 │
│                                                                 │
│  CLIENT                                                         │
│  Email: pierre.dupont@email.com                                │
│  Carte: •••• •••• •••• 4242 (Visa)                             │
│                                                                 │
│  MÉTADONNÉES                                                    │
│  project_id: 7                                                  │
│  project_name: Mon Super Projet                                │
│  contribution_id: 32                                           │
│                                                                 │
│  [Rembourser] [Voir la charge]                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Les informations importantes:**
- **pi_xxx:** C'est l'identifiant unique du paiement (PaymentIntent)
- **Métadonnées:** Informations sur le projet Fiatope associé
- **Bouton Rembourser:** Pour rendre l'argent au contributeur

## 3.5 Section CONNECT - Les porteurs de projet

**C'est LA section la plus importante pour vous!**

**Pour y accéder:** Cliquez sur "Connect" dans le menu de gauche.

### 3.5.1 Vue d'ensemble des comptes

```
┌─────────────────────────────────────────────────────────────────┐
│  COMPTES CONNECTÉS                                              │
├─────────────────────────────────────────────────────────────────┤
│  [Tous] [Activés] [Limités] [En attente]           [Rechercher] │
├─────────────────────────────────────────────────────────────────┤
│  COMPTE              EMAIL                 STATUT    CRÉÉ       │
├─────────────────────────────────────────────────────────────────┤
│  acct_1SqXU1Gsu...   pierre@mail.com     ✅ Activé   15 jan    │
│  acct_1SqXezGzb...   marie@mail.com      ⚠️ Limité   16 jan    │
│  acct_1SqY8kHja...   jean@mail.com       🔄 En cours 17 jan    │
└─────────────────────────────────────────────────────────────────┘
```

### 3.5.2 Comprendre les statuts des comptes

| Statut | Icône | Signification | Que faire ? |
|--------|-------|---------------|-------------|
| **Activé** | ✅ | Tout est bon! Le porteur peut recevoir de l'argent | Rien, tout va bien |
| **Limité** | ⚠️ | Il manque des informations ou documents | Contacter le porteur |
| **En cours** | 🔄 | Le porteur n'a pas fini son inscription | Attendre ou relancer |
| **Restreint** | 🚫 | Stripe a bloqué le compte (problème grave) | Contacter Stripe |

### 3.5.3 Voir les détails d'un compte connecté

**Cliquez sur un compte** pour voir ses détails:

```
┌─────────────────────────────────────────────────────────────────┐
│  COMPTE acct_1SqXU1GsuyeZQUNK                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📋 INFORMATIONS                                                │
│  Nom: Pierre Dupont                                            │
│  Email: pierre@mail.com                                        │
│  Pays: France                                                  │
│  Créé le: 15 janvier 2026                                      │
│                                                                 │
│  ✅ STATUT: Activé                                              │
│  ✅ Paiements activés                                           │
│  ✅ Virements activés                                           │
│                                                                 │
│  💰 SOLDE                                                       │
│  Disponible: 142,50 €                                          │
│  En attente: 0,00 €                                            │
│                                                                 │
│  📊 ACTIVITÉ                                                    │
│  Paiements reçus: 1                                            │
│  Montant total: 150,00 €                                       │
│  Transferts effectués: 1                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.5.4 Que faire si un compte est "Limité" ?

**Étape 1:** Cliquez sur le compte limité

**Étape 2:** Regardez la section "Exigences" ou "Requirements"

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚠️ EXIGENCES EN ATTENTE                                        │
├─────────────────────────────────────────────────────────────────┤
│  Les éléments suivants sont requis pour activer ce compte:     │
│                                                                 │
│  ❌ Document d'identité                                         │
│     Le document fourni n'est pas lisible                       │
│                                                                 │
│  ❌ Adresse                                                      │
│     L'adresse fournie est incomplète                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Étape 3:** Contactez le porteur et expliquez-lui ce qu'il doit corriger

**Modèle d'email à envoyer:**
```
Objet: Action requise pour recevoir vos fonds - Fiatope

Bonjour [Prénom du porteur],

Pour que vous puissiez recevoir les fonds de votre campagne 
"[Nom du projet]", nous avons besoin que vous complétiez 
votre profil de paiement.

Voici ce qui manque:
- [Document d'identité: le document fourni n'est pas lisible]
- [Adresse: l'adresse fournie est incomplète]

Pour corriger cela:
1. Connectez-vous sur Fiatope
2. Allez dans votre profil
3. Cliquez sur "Compléter mon profil de paiement"
4. Suivez les instructions

Si vous avez des questions, n'hésitez pas à me contacter.

Cordialement,
L'équipe Fiatope
```

## 3.6 Section SOLDE - L'argent de Fiatope

**Pour y accéder:** Cliquez sur "Solde" dans le menu de gauche.

```
┌─────────────────────────────────────────────────────────────────┐
│  SOLDE                                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  💰 SOLDE DISPONIBLE                                            │
│  EUR: 1,234.56 €                                               │
│                                                                 │
│  ⏳ SOLDE EN ATTENTE                                            │
│  EUR: 567.89 €                                                 │
│                                                                 │
│  📅 PROCHAINS VIREMENTS                                         │
│  20 jan: 234.56 € → FR76 1234 5678 9012 ****                  │
│  22 jan: 333.33 € → FR76 1234 5678 9012 ****                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Explication:**
- **Solde disponible:** Argent que vous pouvez retirer maintenant
- **Solde en attente:** Argent qui sera disponible dans quelques jours
- **Prochains virements:** Quand l'argent sera envoyé sur votre compte bancaire

## 3.7 Section TRANSFERTS - Argent envoyé aux porteurs

**Pour y accéder:** Cliquez sur "Transferts" (sous "Connect") dans le menu.

```
┌─────────────────────────────────────────────────────────────────┐
│  TRANSFERTS                                                     │
├─────────────────────────────────────────────────────────────────┤
│  MONTANT    DESTINATION         DESCRIPTION       DATE   STATUT │
├─────────────────────────────────────────────────────────────────┤
│  142,50 €  acct_1SqXU1Gsu...   project_7        18 jan  ✅ Payé │
│   95,00 €  acct_1SqXezGzb...   project_5        15 jan  ✅ Payé │
│  285,00 €  acct_1SqY8kHja...   project_3        10 jan  ✅ Payé │
└─────────────────────────────────────────────────────────────────┘
```

**Ce que ça montre:** Chaque fois que Fiatope envoie de l'argent à un porteur de projet, ça apparaît ici.

---

# 4. L'INTERFACE FIATOPE ADMIN {#4-interface-fiatope}

## 4.1 Comment accéder à l'admin Fiatope

1. **Ouvrez votre navigateur**
2. **Allez sur:** https://www.fiatope.com/admin (ou votre URL d'admin)
3. **Connectez-vous** avec votre compte administrateur

## 4.2 Le tableau de bord admin

```
┌─────────────────────────────────────────────────────────────────┐
│  FIATOPE ADMIN                           [Bonjour, Admin] 🔔    │
├─────────────────────────────────────────────────────────────────┤
│  📊 STATISTIQUES                                                │
│  • Projets actifs: 12                                          │
│  • Contributions aujourd'hui: 5                                │
│  • Montant collecté ce mois: 2,450 €                           │
│                                                                 │
│  📋 ACTIONS RAPIDES                                             │
│  [Voir les projets] [Voir les utilisateurs] [Voir les paiements]│
│                                                                 │
│  🔔 ALERTES                                                     │
│  • 2 projets en attente de validation                          │
│  • 1 porteur avec profil Stripe incomplet                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 4.3 Gérer les projets

**Pour y accéder:** Cliquez sur "Projets" dans le menu admin.

### 4.3.1 Liste des projets

```
┌─────────────────────────────────────────────────────────────────┐
│  PROJETS                                   [+ Nouveau] [Filtrer]│
├─────────────────────────────────────────────────────────────────┤
│  NOM                    PORTEUR    OBJECTIF   COLLECTÉ   STATUT │
├─────────────────────────────────────────────────────────────────┤
│  Super Projet 1         Pierre     1000 €     1500 €     🟢 En ligne │
│  Projet Écolo           Marie      5000 €     2000 €     🟢 En ligne │
│  Innovation Tech        Jean       2000 €     0 €        🟡 Brouillon│
│  Aide Humanitaire       Paul       3000 €     3200 €     ✅ Réussi  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3.2 Détails d'un projet

**Cliquez sur un projet** pour voir ses détails:

```
┌─────────────────────────────────────────────────────────────────┐
│  PROJET: Super Projet 1                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📋 INFORMATIONS                                                │
│  ID: 7                                                         │
│  Porteur: Pierre Dupont (pierre@mail.com)                      │
│  Objectif: 1000 €                                              │
│  Collecté: 1500 € (150%)                                       │
│  Fin de campagne: 17 février 2026                              │
│                                                                 │
│  💳 STRIPE                                                      │
│  Stripe activé: ✅ Oui                                          │
│  Compte connecté: acct_1SqXU1GsuyeZQUNK                        │
│  Onboarding complet: ✅ Oui                                     │
│  Réglé: ❌ Non (campagne en cours)                              │
│                                                                 │
│  💰 CONTRIBUTIONS (3)                                           │
│  • Jean Martin: 150 € - 18 jan - ✅ Confirmé                   │
│  • Marie Duval: 100 € - 16 jan - ✅ Confirmé                   │
│  • Paul Blanc: 50 € - 15 jan - ✅ Confirmé                     │
│                                                                 │
│  [Activer Stripe] [Voir sur Stripe] [Forcer transfert]         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3.3 Activer Stripe pour un projet

**Quand le faire:** Quand un nouveau projet est validé et prêt à recevoir des contributions.

**Comment faire:**
1. Allez sur la page du projet
2. Cliquez sur le bouton **"Activer Stripe"**
3. Confirmez l'action
4. Le porteur recevra un email pour compléter son profil Stripe

## 4.4 Gérer les utilisateurs

**Pour y accéder:** Cliquez sur "Utilisateurs" dans le menu admin.

### 4.4.1 Voir le profil Stripe d'un utilisateur

```
┌─────────────────────────────────────────────────────────────────┐
│  UTILISATEUR: Pierre Dupont                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📋 INFORMATIONS                                                │
│  Email: pierre@mail.com                                        │
│  Inscrit le: 10 janvier 2026                                   │
│                                                                 │
│  💳 STRIPE CONNECT                                              │
│  Compte Stripe: acct_1SqXU1GsuyeZQUNK                          │
│  Onboarding: ✅ Complet                                         │
│  Paiements activés: ✅ Oui                                      │
│  Virements activés: ✅ Oui                                      │
│                                                                 │
│  📁 SES PROJETS                                                 │
│  • Super Projet 1 (en ligne)                                   │
│  • Projet Innovation (brouillon)                               │
│                                                                 │
│  [Voir sur Stripe] [Renvoyer lien onboarding]                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

# 5. CYCLE DE VIE COMPLET D'UNE CAMPAGNE {#5-cycle-de-vie}

## 5.1 Vue d'ensemble

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   CRÉATION   │───▶│  ONBOARDING  │───▶│   CAMPAGNE   │───▶│     FIN      │
│   PROJET     │    │   STRIPE     │    │   ACTIVE     │    │  CAMPAGNE    │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
  Le porteur          Le porteur          Les gens           Si réussi:
  crée son            complète son        contribuent        → Transfert
  projet              profil Stripe                          Si échoué:
                                                             → Remboursement
```

## 5.2 Étape 1: Création du projet

**Ce qui se passe:**
1. Le porteur crée un compte sur Fiatope
2. Il remplit les informations de son projet:
   - Titre
   - Description
   - Photos/Vidéos
   - Objectif financier
   - Date de fin de campagne
3. Il soumet le projet pour validation

**Ce que vous faites:**
1. Vous recevez une notification "Nouveau projet à valider"
2. Vous examinez le projet
3. Si tout est bon, vous validez et activez Stripe

## 5.3 Étape 2: Onboarding Stripe

**Ce qui se passe:**
1. Le porteur reçoit un email: "Complétez votre profil de paiement"
2. Il clique sur le lien
3. Il est redirigé vers Stripe
4. Il remplit ses informations:
   - Nom, prénom, date de naissance
   - Adresse
   - Téléphone
   - Pièce d'identité
   - IBAN

**Ce que vous surveillez:**
- Dans Stripe Dashboard → Connect → regardez si le compte passe en "Activé"
- Si le compte reste "Limité" après 3 jours, contactez le porteur

## 5.4 Étape 3: Campagne active

**Ce qui se passe:**
1. Le projet est visible sur Fiatope
2. Les contributeurs peuvent donner de l'argent
3. Chaque contribution:
   - Est encaissée par Stripe
   - Apparaît dans le Dashboard Stripe
   - Est enregistrée dans Fiatope
4. Le compteur de la campagne se remplit

**Ce que vous surveillez:**
- Les paiements échoués (carte refusée, etc.)
- Les demandes de remboursement
- L'avancement des campagnes

## 5.5 Étape 4: Fin de campagne

### 5.5.1 Si la campagne RÉUSSIT (objectif atteint)

**Ce qui se passe automatiquement:**
1. Le système calcule le total collecté
2. Il déduit la commission Fiatope (5%)
3. Il transfère le reste au porteur
4. Le porteur reçoit l'argent sur son compte bancaire

**Exemple:**
- Collecté: 1000€
- Commission Fiatope (5%): 50€
- Transféré au porteur: 950€

### 5.5.2 Si la campagne ÉCHOUE (objectif non atteint)

**Ce qui se passe:**
1. Tous les contributeurs sont remboursés
2. Le porteur ne reçoit rien
3. Fiatope ne prend pas de commission

**Ce que vous devez faire:**
1. Aller dans Fiatope Admin
2. Sélectionner le projet
3. Cliquer sur "Traiter fin de campagne"
4. Confirmer les remboursements

---

# 6. GUIDE PAS-À-PAS: CRÉER ET GÉRER UN PROJET {#6-guide-projet}

## 6.1 Valider un nouveau projet

**Situation:** Un porteur vient de soumettre un projet pour validation.

**Étapes:**

1. **Connectez-vous à l'admin Fiatope**
   - URL: https://www.fiatope.com/admin
   - Entrez vos identifiants

2. **Allez dans les projets en attente**
   - Menu → Projets → Filtrer par "En attente de validation"

3. **Examinez le projet**
   - Cliquez sur le projet
   - Vérifiez:
     - [ ] La description est claire et complète
     - [ ] Les photos sont de bonne qualité
     - [ ] L'objectif financier est réaliste
     - [ ] La date de fin est raisonnable
     - [ ] Le projet respecte les règles de Fiatope

4. **Validez le projet**
   - Cliquez sur "Valider"
   - Le projet passe en statut "Validé"

5. **Activez Stripe pour le projet**
   - Sur la page du projet, cliquez sur "Activer Stripe"
   - Le porteur recevra automatiquement un email

## 6.2 Aider un porteur à compléter son onboarding Stripe

**Situation:** Un porteur vous contacte car il n'arrive pas à compléter son profil Stripe.

**Étapes:**

1. **Identifiez le problème sur Stripe**
   - Allez sur https://dashboard.stripe.com
   - Menu → Connect → Comptes
   - Cherchez le compte du porteur (par email)
   - Cliquez dessus
   - Regardez la section "Exigences"

2. **Problèmes courants et solutions:**

   | Problème | Solution à donner au porteur |
   |----------|------------------------------|
   | "Document illisible" | "Prenez une nouvelle photo de votre pièce d'identité avec plus de lumière" |
   | "Adresse incomplète" | "Ajoutez le code postal et la ville" |
   | "IBAN invalide" | "Vérifiez que vous avez copié tous les caractères de votre RIB" |
   | "Date de naissance" | "La date doit être au format JJ/MM/AAAA" |

3. **Renvoyez le lien d'onboarding si nécessaire**
   - Dans Fiatope Admin → Utilisateurs → [le porteur]
   - Cliquez sur "Renvoyer lien onboarding"
   - Le porteur recevra un nouvel email

## 6.3 Vérifier qu'un projet est prêt à recevoir des paiements

**Situation:** Avant le lancement d'une campagne, vous voulez vérifier que tout est en place.

**Checklist:**

- [ ] **Le projet est validé sur Fiatope**
  - Statut = "En ligne" ou "Validé"
  
- [ ] **Stripe est activé pour le projet**
  - Dans Fiatope Admin → Projet → "Stripe activé: Oui"
  
- [ ] **Le compte Stripe du porteur est complet**
  - Sur Stripe Dashboard → Connect → [compte] → Statut = "Activé"
  
- [ ] **Les paiements sont activés pour ce compte**
  - Sur la page du compte Stripe: "Paiements activés: Oui"
  
- [ ] **Les virements sont activés**
  - Sur la page du compte Stripe: "Virements activés: Oui"

---

# 7. GUIDE PAS-À-PAS: GÉRER LES CONTRIBUTIONS {#7-guide-contributions}

## 7.1 Voir toutes les contributions d'un projet

**Méthode 1: Via Fiatope Admin**
1. Admin → Projets → [le projet]
2. Descendez jusqu'à la section "Contributions"
3. Vous voyez la liste de tous les contributeurs et montants

**Méthode 2: Via Stripe Dashboard**
1. Dashboard Stripe → Paiements
2. Cliquez sur "Filtrer"
3. Ajoutez un filtre: Métadonnées → project_id = [numéro du projet]
4. Vous voyez tous les paiements pour ce projet

## 7.2 Rembourser une contribution

**Situation:** Un contributeur demande un remboursement.

**Règles:**
- Pendant la campagne: Le remboursement est possible
- Après campagne réussie: L'argent est déjà transféré au porteur, plus compliqué
- Après campagne échouée: Normalement déjà remboursé automatiquement

**Étapes pour rembourser:**

1. **Trouvez le paiement sur Stripe**
   - Dashboard Stripe → Paiements
   - Cherchez par email du contributeur ou montant
   - Cliquez sur le paiement

2. **Vérifiez que c'est le bon paiement**
   - Regardez les métadonnées (project_id, contribution_id)
   - Vérifiez le montant

3. **Effectuez le remboursement**
   - Cliquez sur le bouton "Rembourser"
   - Choisissez le montant (total ou partiel)
   - Entrez une raison (optionnel mais recommandé)
   - Confirmez

4. **Le contributeur sera remboursé**
   - Délai: 5-10 jours ouvrés sur sa carte bancaire
   - Il recevra un email de confirmation de Stripe

## 7.3 Traiter un paiement échoué

**Situation:** Un contributeur vous dit que son paiement n'a pas fonctionné.

**Étapes:**

1. **Trouvez le paiement échoué**
   - Dashboard Stripe → Paiements → Filtre: "Échoués"
   - Cherchez par email ou date

2. **Identifiez la raison de l'échec**
   - Cliquez sur le paiement
   - Regardez le message d'erreur:

   | Message | Signification | Solution |
   |---------|---------------|----------|
   | "Fonds insuffisants" | Pas assez d'argent sur la carte | Demander au contributeur d'utiliser une autre carte |
   | "Carte expirée" | La carte n'est plus valide | Utiliser une carte à jour |
   | "Refusé par la banque" | La banque a bloqué | Contacter sa banque |
   | "Numéro incorrect" | Erreur de saisie | Réessayer en vérifiant le numéro |

3. **Contactez le contributeur** (si nécessaire)
   - Expliquez le problème
   - Proposez de réessayer

---

# 8. GUIDE PAS-À-PAS: FIN DE CAMPAGNE {#8-fin-campagne}

## 8.1 Campagne réussie - Transférer les fonds

**Situation:** La campagne est terminée et l'objectif est atteint.

**Ce qui doit se passer:**
1. Calculer le montant total collecté
2. Déduire la commission Fiatope (5%)
3. Transférer le reste au porteur

**Étapes:**

1. **Vérifiez que la campagne est bien terminée**
   - Fiatope Admin → Projet → Date de fin passée ✅
   - Objectif atteint: Oui ✅

2. **Vérifiez que le compte Stripe du porteur est prêt**
   - Dashboard Stripe → Connect → [compte]
   - Statut: Activé ✅
   - Virements activés: Oui ✅

3. **Lancez le transfert**
   - Fiatope Admin → Projet → "Traiter fin de campagne"
   - Ou via la commande technique (voir section 10)

4. **Vérifiez que le transfert a été effectué**
   - Dashboard Stripe → Connect → Transferts
   - Vous devez voir un nouveau transfert vers le compte du porteur

5. **Informez le porteur**
   - Envoyez un email de félicitations
   - Indiquez le montant transféré
   - Précisez le délai pour recevoir l'argent (2-7 jours)

## 8.2 Campagne échouée - Rembourser les contributeurs

**Situation:** La campagne est terminée mais l'objectif n'est pas atteint.

**Ce qui doit se passer:**
- Tous les contributeurs sont remboursés intégralement
- Le porteur ne reçoit rien
- Fiatope ne prend pas de commission

**Étapes:**

1. **Vérifiez que la campagne est bien terminée et échouée**
   - Fiatope Admin → Projet
   - Date de fin passée ✅
   - Objectif atteint: Non ❌

2. **Lancez les remboursements**
   - Fiatope Admin → Projet → "Traiter fin de campagne"
   - Le système va automatiquement rembourser chaque contribution

3. **Vérifiez que les remboursements sont effectués**
   - Dashboard Stripe → Paiements → Filtre: "Remboursés"
   - Vous devez voir tous les paiements du projet en statut "Remboursé"

4. **Informez les parties concernées**
   - Email au porteur: La campagne n'a pas atteint son objectif
   - Les contributeurs reçoivent automatiquement un email de Stripe pour le remboursement

## 8.3 Tableau récapitulatif fin de campagne

| Situation | Objectif atteint ? | Action | Résultat |
|-----------|-------------------|--------|----------|
| Campagne réussie | ✅ Oui | Transfert | Porteur reçoit 95% |
| Campagne échouée | ❌ Non | Remboursement | Contributeurs remboursés 100% |
| Campagne en cours | - | Rien | Attendre la date de fin |

---

# 9. PROBLÈMES COURANTS ET SOLUTIONS {#9-problemes}

## 9.1 "Le porteur ne reçoit pas l'email d'onboarding"

**Causes possibles:**
1. Email dans les spams
2. Adresse email incorrecte
3. Problème d'envoi

**Solutions:**
1. Demander au porteur de vérifier ses spams
2. Vérifier l'adresse email dans Fiatope Admin
3. Renvoyer le lien manuellement:
   - Fiatope Admin → Utilisateur → "Renvoyer lien onboarding"

## 9.2 "Le compte Stripe reste en statut Limité"

**Causes possibles:**
1. Document d'identité illisible
2. Informations incomplètes
3. Problème de vérification bancaire

**Solutions:**
1. Sur Stripe Dashboard → Connect → [compte] → voir les "Exigences"
2. Contacter le porteur avec les informations manquantes
3. Le porteur doit refaire son onboarding avec les bonnes infos

## 9.3 "Un paiement apparaît sur Stripe mais pas sur Fiatope"

**Causes possibles:**
1. Webhook non reçu
2. Erreur dans le traitement

**Solutions:**
1. Vérifier sur Stripe Dashboard → Développeurs → Webhooks → Événements
2. Chercher l'événement "payment_intent.succeeded"
3. Si "Échoué", cliquer pour voir l'erreur
4. Contacter le support technique si nécessaire

## 9.4 "Le transfert au porteur a échoué"

**Causes possibles:**
1. Compte Stripe pas complètement activé
2. IBAN invalide
3. Solde insuffisant sur le compte Fiatope

**Solutions:**
1. Vérifier le statut du compte Connect
2. Demander au porteur de vérifier son IBAN
3. Vérifier le solde dans Stripe Dashboard → Solde
4. Réessayer le transfert une fois le problème résolu

## 9.5 "Un contributeur veut être remboursé mais la campagne est réussie"

**Situation:** L'argent a déjà été transféré au porteur.

**Options:**
1. Contacter le porteur pour qu'il rembourse directement le contributeur
2. Faire un remboursement depuis le solde Fiatope (si politique le permet)
3. Expliquer au contributeur que le remboursement n'est plus possible

**Conseil:** Avoir une politique de remboursement claire dans les CGV de Fiatope.

---

# 10. COMMANDES TECHNIQUES (POUR DÉVELOPPEURS) {#10-commandes}

## 10.1 Comment exécuter une commande

**Prérequis:** Accès au serveur Fiatope via terminal/SSH

**Commande de base:**
```bash
# Se connecter au serveur
ssh utilisateur@serveur-fiatope.com

# Aller dans le dossier du projet
cd /chemin/vers/fiatope

# Exécuter une commande Rails
ruby bin/rails runner "VOTRE_COMMANDE"

# Ou via rake
bundle exec rake nom_de_la_tache
```

## 10.2 Commandes pour les utilisateurs

```ruby
# Trouver un utilisateur par email
user = User.find_by(email: 'email@exemple.com')

# Voir le statut Stripe d'un utilisateur
puts "Compte Stripe: #{user.stripe_account_id}"
puts "Onboarding complet: #{user.stripe_onboarding_complete?}"

# Créer un lien d'onboarding
url = user.stripe_account_onboarding_url(
  refresh_url: "https://fiatope.com/stripe/connect/refresh",
  return_url: "https://fiatope.com/stripe/connect/return"
)
puts "Lien: #{url}"
```

## 10.3 Commandes pour les projets

```ruby
# Trouver un projet par ID
project = Project.find(7)

# Voir le statut Stripe du projet
puts "Stripe activé: #{project.use_stripe?}"
puts "Compte connecté: #{project.stripe_account_id}"
puts "Réglé: #{project.stripe_settled_at.present?}"
puts "Transfer ID: #{project.stripe_transfer_id}"

# Activer Stripe pour un projet
project.enable_stripe!

# Voir les contributions Stripe
project.contributions.where(payment_method: 'Stripe').each do |c|
  puts "#{c.id}: #{c.value}€ - #{c.state}"
end
```

## 10.4 Commandes pour les transferts

```bash
# Voir le statut des campagnes
bundle exec rake stripe:crowdfunding:status

# Forcer un transfert pour un projet réussi
bundle exec rake "stripe:crowdfunding:force_transfer[ID_PROJET]"

# Forcer le remboursement pour un projet échoué
bundle exec rake "stripe:crowdfunding:force_refund[ID_PROJET]"
```

## 10.5 Commandes pour vérifier les paiements

```bash
# Vérifier les contributions Stripe
bundle exec rake stripe:test:verify_stripe_payments
```

```ruby
# Récupérer les détails d'un paiement
pi = Stripe::PaymentIntent.retrieve('pi_xxx')
puts "Montant: #{pi.amount / 100.0}€"
puts "Statut: #{pi.status}"

# Récupérer les détails d'un transfert
transfer = Stripe::Transfer.retrieve('tr_xxx')
puts "Montant: #{transfer.amount / 100.0}€"
puts "Destination: #{transfer.destination}"
```

---

# 11. GLOSSAIRE - LES MOTS EXPLIQUÉS {#11-glossaire}

| Terme | Explication simple |
|-------|-------------------|
| **API** | Un moyen pour deux systèmes informatiques de communiquer |
| **Charge** | L'encaissement d'un paiement par carte |
| **Commission** | Le pourcentage que Fiatope garde sur chaque contribution |
| **Connect** | La fonctionnalité Stripe qui permet de gérer plusieurs destinataires |
| **Contribution** | L'argent donné par quelqu'un pour soutenir un projet |
| **Crowdfunding** | Financement participatif - récolter de l'argent auprès de nombreuses personnes |
| **Dashboard** | Tableau de bord - la page principale de gestion |
| **Express** | Type de compte Stripe géré par Stripe (moins de travail pour vous) |
| **IBAN** | Numéro de compte bancaire international |
| **Métadonnées** | Informations supplémentaires attachées à un paiement |
| **Onboarding** | Le processus d'inscription et de vérification d'un porteur |
| **PaymentIntent** | Objet Stripe représentant une intention de paiement |
| **Porteur de projet** | La personne qui crée un projet et reçoit les fonds |
| **Refund** | Remboursement - rendre l'argent à un contributeur |
| **Settlement** | Règlement - le moment où l'argent est envoyé au porteur |
| **Stripe** | Le service de paiement en ligne utilisé par Fiatope |
| **Transfer** | L'envoi d'argent depuis le compte Fiatope vers un porteur |
| **Webhook** | Notification automatique envoyée par Stripe à Fiatope |

---

# 📞 CONTACTS ET SUPPORT

## Support Stripe
- Site: https://support.stripe.com
- Dashboard: https://dashboard.stripe.com

## Support Fiatope
- Email: support@fiatope.com
- Admin: https://www.fiatope.com/admin

---

**Document créé pour Fiatope**
**Version: 1.0**
**Dernière mise à jour: 18 janvier 2026**
**Auteur: Équipe technique Fiatope**

---

*Ce document est confidentiel et destiné uniquement aux administrateurs de Fiatope.*
