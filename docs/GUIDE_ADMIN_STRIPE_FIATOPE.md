# 🎯 Guide Administrateur - Stripe Connect Fiatope

> **Document officiel** - Version finale validée
> Dernière mise à jour: Janvier 2026

---

## 📋 Table des matières

1. [Comprendre Stripe Connect](#1-comprendre-stripe-connect)
2. [Interface Admin - Gestion des projets](#2-interface-admin---gestion-des-projets)
3. [Workflow complet étape par étape](#3-workflow-complet-étape-par-étape)
4. [Structure des frais et commissions](#4-structure-des-frais-et-commissions)
5. [Statuts et indicateurs visuels](#5-statuts-et-indicateurs-visuels)
6. [FAQ et dépannage](#6-faq-et-dépannage)

---

## 1. Comprendre Stripe Connect

### Architecture utilisée

Fiatope utilise **Stripe Connect** avec le modèle **"Separate Charges and Transfers"**:

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUX DES PAIEMENTS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Contributeur                                                   │
│      │                                                          │
│      ▼                                                          │
│  ┌─────────────────┐                                           │
│  │  Paiement Stripe │  (100€)                                  │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────────────────────────────┐                   │
│  │      COMPTE PLATEFORME FIATOPE          │                   │
│  │  ─────────────────────────────────────  │                   │
│  │  Reçu: 100€                             │                   │
│  │  Frais Stripe: -2,90€ (2.9% + 0.25€)    │                   │
│  │  Net disponible: 97,10€                 │                   │
│  └────────┬────────────────────────────────┘                   │
│           │                                                     │
│           │  FIN DE CAMPAGNE RÉUSSIE                           │
│           ▼                                                     │
│  ┌─────────────────────────────────────────┐                   │
│  │         RÈGLEMENT FINAL                  │                   │
│  │  ─────────────────────────────────────  │                   │
│  │  Net après Stripe: 97,10€               │                   │
│  │  Commission Fiatope (5%): -4,86€        │                   │
│  │  Transfert au porteur: 92,24€           │                   │
│  └────────┬────────────────────────────────┘                   │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────────────────────────────┐                   │
│  │    COMPTE CONNECTÉ DU PORTEUR           │                   │
│  │    (Stripe Express)                      │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Concepts clés

| Concept | Description |
|---------|-------------|
| **Compte Plateforme** | Le compte Stripe principal de Fiatope qui reçoit tous les paiements |
| **Compte Connecté** | Compte Stripe Express créé pour chaque porteur de projet |
| **Onboarding** | Processus où le porteur complète son profil Stripe (identité, coordonnées bancaires) |
| **Transfer** | Envoi des fonds du compte plateforme vers le compte connecté |
| **Refund** | Remboursement d'un contributeur (campagne échouée) |

### Point important: 1 Compte Connecté = 1 Porteur (pas 1 projet)

> **Le compte Stripe Connect est lié à l'UTILISATEUR (porteur), pas au projet.**
> 
> Si un porteur crée plusieurs projets, ils partagent tous le même compte Stripe connecté.
> Une fois l'onboarding complété, tous ses projets sont automatiquement prêts pour Stripe.

---

## 2. Interface Admin - Gestion des projets

### Accéder à l'admin

1. Connectez-vous en tant qu'administrateur
2. Allez à `/admin/projects`

### Colonne "Stripe" dans la liste des projets

| Indicateur | Signification |
|------------|---------------|
| ❌ Non activé | Stripe n'est pas encore activé pour ce projet |
| 🔗 Rattacher | Le porteur a déjà un compte Stripe (d'un autre projet), cliquer pour l'activer |
| ⏳ Onboarding | Stripe activé mais le porteur n'a pas complété son profil |
| ✅ Prêt | Le porteur a complété son profil, prêt pour les paiements |
| 💳 X contrib. | Nombre de contributions Stripe en attente de traitement |
| 💰 Transféré | Les fonds ont été transférés au porteur |
| ↩️ Remboursé | Les contributeurs ont été remboursés |
| 💰 Réglé | Le projet a été réglé (transfert ou remboursement effectué) |

### Actions disponibles (menu déroulant)

| Action | Condition d'apparition | Description |
|--------|------------------------|-------------|
| **Activer Stripe** | Stripe non activé | Crée ou rattache le compte Stripe du porteur |
| **Lien Onboarding Stripe** | Stripe activé + onboarding non complété | Génère un lien pour que le porteur complète son profil |
| **💰 Transférer au porteur** | Contributions Stripe EN ATTENTE + onboarding complété + pas déjà transféré | Transfère les fonds collectés au porteur (montant NET affiché) |
| **↩️ Rembourser contributeurs** | Contributions Stripe EN ATTENTE + pas déjà transféré + pas déjà remboursé | Rembourse tous les contributeurs

> **⚠️ RÈGLES CRITIQUES DE SÉCURITÉ:**
> 
> 1. **Transfert**: On transfère ce qu'on a collecté au porteur, **même si l'objectif n'est pas atteint**
> 2. **Remboursement**: Peut être fait **à tout moment** MAIS **uniquement AVANT le transfert**
> 3. **IMPOSSIBLE de rembourser après un transfert** - les fonds ne sont plus sur notre compte!
> 4. **Les boutons n'apparaissent QUE s'il y a des contributions EN ATTENTE** (non encore traitées)
> 5. **Le montant affiché est le NET** (après frais Stripe et commission Fiatope)

---

## 3. Workflow complet étape par étape

### Étape 1: Activer Stripe pour un projet

1. Dans la liste des projets, trouvez le projet
2. Cliquez sur le menu déroulant (⋮)
3. Cliquez sur **"Activer Stripe"**

**Résultats possibles:**
- ✅ Si le porteur a déjà un compte Stripe configuré → Message "Stripe activé! Le porteur a déjà un compte configuré"
- ⏳ Si nouveau porteur → Message "Stripe activé! Le porteur doit compléter son profil Stripe"

### Étape 2: Générer le lien d'onboarding (si nécessaire)

Si le porteur n'a pas encore complété son profil Stripe:

1. Cliquez sur le menu déroulant (⋮)
2. Cliquez sur **"Lien Onboarding Stripe"**
3. Un encadré vert apparaît en haut de la page avec le lien
4. Cliquez sur **"📋 Copier"**
5. Envoyez ce lien au porteur par email

**Important:**
- Le lien expire dans **24 heures**
- Le porteur doit remplir: identité, adresse, coordonnées bancaires
- Une fois complété, le statut passe automatiquement à "✅ Prêt"

### Étape 3: Attendre la fin de la campagne

- Les contributions Stripe arrivent automatiquement
- Chaque contribution est stockée avec son `payment_id` Stripe
- Le porteur peut suivre l'avancement sur sa page projet

### Étape 4: Régler la campagne

**Option A: Transférer les fonds au porteur**

> Utilisable dès qu'il y a des contributions Stripe, **peu importe si l'objectif est atteint ou non**.

1. Le bouton **"💰 Transférer au porteur"** apparaît si:
   - Des contributions Stripe confirmées existent
   - L'onboarding du porteur est complété
   - Le projet n'a pas déjà été transféré
2. Cliquez dessus et confirmez
3. Les fonds (moins frais Stripe et commission Fiatope) sont transférés
4. Le porteur reçoit l'argent sur son compte bancaire sous 2-7 jours ouvrés

**Option B: Rembourser les contributeurs**

> Utilisable **À TOUT MOMENT** en cas de problème avec le porteur ou le projet.

1. Le bouton **"↩️ Rembourser contributeurs"** apparaît si:
   - Des contributions Stripe non remboursées existent
   - Le projet n'a pas déjà été remboursé
2. Cliquez dessus et confirmez
3. Chaque contributeur est remboursé automatiquement
4. Les fonds apparaissent sur leur carte sous 5-10 jours ouvrés

> **⚠️ Attention**: Une fois le transfert ou le remboursement effectué, l'action est irréversible.

---

## 4. Structure des frais et commissions

### Formule de calcul

```
Pour une contribution de 100€:

1. Frais Stripe prélevés à la source:
   - Cartes EU: 1,4% + 0,25€ = 1,65€
   - Cartes non-EU: 2,9% + 0,25€ = 3,15€
   - Moyenne estimée: ~2,5% + 0,25€ = 2,75€

2. Montant NET après Stripe: 100€ - 2,75€ = 97,25€

3. Commission Fiatope (5% du NET):
   97,25€ × 5% = 4,86€

4. Montant final pour le porteur:
   97,25€ - 4,86€ = 92,39€
```

### Tableau récapitulatif

| Collecte brute | Frais Stripe (~2.75%) | Net après Stripe | Commission Fiatope (5%) | Pour le porteur |
|----------------|----------------------|------------------|-------------------------|-----------------|
| 100€ | 2,75€ | 97,25€ | 4,86€ | 92,39€ |
| 500€ | 13,75€ | 486,25€ | 24,31€ | 461,94€ |
| 1 000€ | 27,50€ | 972,50€ | 48,63€ | 923,87€ |
| 5 000€ | 137,50€ | 4 862,50€ | 243,13€ | 4 619,37€ |
| 10 000€ | 275,00€ | 9 725,00€ | 486,25€ | 9 238,75€ |

> **Note:** Les frais Stripe exacts sont récupérés via l'API Stripe pour chaque transaction.
> Si non disponibles, une estimation de 2,5% + 0,25€ est utilisée.

---

## 5. Statuts et indicateurs visuels

### États du projet dans l'admin

| État projet | Stripe activé | Onboarding | Contributions | Action admin |
|-------------|---------------|------------|---------------|--------------|
| draft/online | Non | - | - | Activer Stripe |
| draft/online | Oui | En attente | - | Générer lien onboarding |
| draft/online | Oui | Complété | Oui | Transférer OU Rembourser |
| any | Oui | Complété | Oui | Transférer au porteur |
| any | Oui | - | Oui | Rembourser contributeurs |
| - | Oui | - | Traitées | Rien (déjà réglé) |

> **Note**: L'état de la campagne (successful/failed) n'influence plus les actions disponibles.

### Logs de règlement

Chaque règlement génère des logs détaillés dans la console Rails:

```
CampaignSettlement: Projet "Mon Super Projet"
  - Brut collecté: 1000€
  - Frais Stripe: 27.50€
  - Net après Stripe: 972.50€
  - Commission Fiatope (5% du net): 48.63€
  - Transfert au porteur: 923.87€
CampaignSettlement: Transfert tr_xxx créé avec succès
```

---

## 6. FAQ et dépannage

### Q: Le porteur a déjà un compte Stripe d'un autre projet. Que faire?

**R:** Cliquez simplement sur "Activer Stripe". Le système détecte automatiquement le compte existant et le rattache au nouveau projet. Tous les projets du même porteur partagent le même compte Stripe.

### Q: Le lien d'onboarding a expiré. Comment en générer un nouveau?

**R:** Cliquez à nouveau sur "Lien Onboarding Stripe". Un nouveau lien de 24h sera généré.

### Q: La campagne est terminée mais le bouton de règlement n'apparaît pas.

**R:** Vérifiez:
1. Le porteur a complété son onboarding (statut "✅ Prêt")
2. La campagne est bien expirée (date de fin dépassée)
3. Le projet n'a pas déjà été réglé

### Q: Un contributeur demande un remboursement avant la fin de campagne.

**R:** Vous pouvez utiliser le bouton "Rembourser contributeurs" à tout moment pour rembourser TOUS les contributeurs. **ATTENTION**: Cette action n'est possible que si les fonds n'ont pas encore été transférés au porteur. Pour un remboursement individuel, utilisez la console Stripe.

### Q: Pourquoi le bouton de remboursement n'apparaît pas alors que j'ai des contributions?

**R:** Vérifiez:
1. Les contributions sont bien **EN ATTENTE** (pas déjà transférées ou remboursées)
2. Le projet n'a **PAS** déjà été transféré (`stripe_settlement_type != 'transferred'`)
3. Le projet n'a **PAS** déjà été remboursé (`stripe_settlement_type != 'refunded'`)

### Q: J'ai eu une erreur "insufficient funds" lors du transfert.

**R:** Cette erreur ne devrait plus se produire car le système utilise maintenant `source_transaction` pour lier les transferts aux charges originaux. Si elle persiste, vérifiez que les contributions ont bien un `stripe_charge_id` stocké.

### Q: Comment vérifier le statut d'un compte Stripe?

**R:** Dans la colonne Stripe de l'admin:
- Survolez l'indicateur pour voir l'ID du compte
- Le statut "✅ Prêt" signifie `charges_enabled` et `payouts_enabled` sont true

### Q: Les frais Stripe affichés sont-ils exacts?

**R:** Oui. Le système récupère les frais réels via l'API Stripe (`BalanceTransaction.fee`). Si indisponibles, une estimation de 2,5% + 0,25€ est utilisée.

---

## 📞 Support technique

Pour toute question technique ou problème:
- Consultez les logs Rails pour les détails des erreurs
- Les IDs Stripe (compte, transfert, remboursement) sont stockés dans la base de données

### Colonnes importantes dans la base de données

**Table `users`:**
- `stripe_connect_account_id`: ID du compte Stripe Express
- `stripe_onboarding_complete`: Boolean (onboarding terminé)

**Table `projects`:**
- `use_stripe`: Boolean (Stripe activé)
- `stripe_account_id`: Référence au compte du porteur
- `stripe_transfer_id`: ID du transfert final
- `stripe_settled_at`: Date de règlement
- `stripe_settlement_type`: Type de règlement ('transferred' ou 'refunded')

**Table `contributions`:**
- `payment_id`: ID PaymentIntent Stripe
- `stripe_charge_id`: ID du charge
- `stripe_transferred`: Boolean
- `stripe_refunded`: Boolean

---

*Document rédigé pour l'équipe administrative Fiatope*
