# 📋 ROUTINE OPÉRATIONNELLE STRIPE CONNECT
## Guide pratique pour la gestion quotidienne de Fiatope

---

# 🔄 CYCLE DE VIE D'UN PROJET AVEC STRIPE CONNECT

## Phase 1: Création du projet

### Ce qui se passe automatiquement:
1. Le porteur crée son projet sur Fiatope
2. Le projet est en mode "brouillon" ou "en attente de validation"

### Ce que vous devez faire:
1. **Valider le projet** (si nécessaire selon vos règles)
2. **Activer Stripe pour le projet**:
   - Via l'admin Fiatope, ou
   - Via la console Rails:
   ```ruby
   project = Project.find(ID_DU_PROJET)
   project.enable_stripe!
   ```

### Ce qui se passe ensuite:
- Un compte connecté Express est créé pour le porteur (s'il n'en a pas déjà)
- Le projet est lié à ce compte connecté
- Le porteur reçoit une notification pour compléter son onboarding Stripe

---

## Phase 2: Onboarding du porteur

### Ce que le porteur doit faire:
1. Cliquer sur le lien d'onboarding (envoyé par email ou visible sur Fiatope)
2. Être redirigé vers Stripe
3. Remplir ses informations:
   - Informations personnelles (nom, date de naissance)
   - Adresse
   - Numéro de téléphone
   - Document d'identité (carte d'identité, passeport)
   - Informations bancaires (IBAN)
4. Revenir sur Fiatope

### Comment vérifier l'état de l'onboarding:

**Sur le Dashboard Stripe:**
1. Aller sur https://dashboard.stripe.com/connect/accounts/overview
2. Trouver le compte du porteur
3. Vérifier l'état:
   - ✅ **Activé** = Prêt à recevoir des paiements
   - ⚠️ **Limité** = Informations manquantes
   - ❌ **Rejeté** = Problème de vérification

**En cas de compte "Limité":**
1. Cliquer sur le compte pour voir les détails
2. Noter les informations manquantes
3. Contacter le porteur pour qu'il complète son profil
4. Le porteur peut reprendre l'onboarding via Fiatope

---

## Phase 3: Collecte des contributions (Modèle Crowdfunding)

### Ce qui se passe automatiquement:
1. Un contributeur clique sur "Payer avec Stripe"
2. Il est redirigé vers Stripe Checkout
3. Il paie avec sa carte
4. **L'argent est collecté sur le compte Fiatope** (pas de transfert immédiat)
5. Fiatope reçoit un webhook et confirme la contribution
6. Le `charge_id` est stocké pour le transfert différé

### Ce que vous devez vérifier:
1. **Les contributions sont bien confirmées** dans Fiatope
2. **Les paiements apparaissent** dans le Dashboard Stripe
3. **Les contributions ont un `stripe_charge_id`** stocké

---

## Phase 4: Fin de campagne et reversement (Crowdfunding)

### Modèle "Separate Charges and Transfers":
L'argent est collecté sur le compte Fiatope pendant toute la campagne. À la fin:

**Si campagne réussie (objectif atteint):**
1. Exécuter le transfert vers le compte connecté du porteur
2. Commission Fiatope déduite automatiquement
3. Le porteur reçoit les fonds sur son compte Stripe
4. Stripe vire sur son compte bancaire (7-14 jours)

**Si campagne échouée (objectif non atteint):**
1. Toutes les contributions sont remboursées
2. Les contributeurs récupèrent leur argent

### Commandes pour gérer les fins de campagne:

```bash
# Voir le statut des campagnes
bundle exec rake stripe:crowdfunding:status

# Traiter automatiquement toutes les campagnes terminées
bundle exec rake stripe:crowdfunding:settle_campaigns

# Forcer le transfert pour un projet spécifique
bundle exec rake stripe:crowdfunding:force_transfer[PROJECT_ID]

# Forcer le remboursement pour un projet spécifique
bundle exec rake stripe:crowdfunding:force_refund[PROJECT_ID]

# Voir les contributions en attente de transfert
bundle exec rake stripe:crowdfunding:pending_transfers
```

### Ce que vous devez faire:
1. **Vérifier quotidiennement** les campagnes terminées avec `rake stripe:crowdfunding:status`
2. **Exécuter le règlement** avec `rake stripe:crowdfunding:settle_campaigns`
3. **Vérifier les erreurs** et traiter manuellement si nécessaire

---

# 📊 TABLEAU DE BORD QUOTIDIEN

## Ce qu'il faut vérifier chaque jour:

### 1. Nouveaux comptes connectés
**Où:** Dashboard Stripe → Connect → Comptes connectés

| À vérifier | Action si problème |
|------------|-------------------|
| Nouveaux comptes créés | Vérifier qu'ils correspondent aux nouveaux projets |
| Comptes "Limités" | Contacter les porteurs pour compléter l'onboarding |
| Comptes "Rejetés" | Investiguer et contacter le porteur |

### 2. Paiements du jour
**Où:** Dashboard Stripe → Paiements

| À vérifier | Action si problème |
|------------|-------------------|
| Paiements "Réussi" | Vérifier qu'ils sont confirmés dans Fiatope |
| Paiements "Échoué" | Vérifier les logs, contacter le contributeur si besoin |
| Paiements "En attente" | Normal, sera traité automatiquement |

### 3. Transferts
**Où:** Dashboard Stripe → Connect → Transferts

| À vérifier | Action si problème |
|------------|-------------------|
| Transferts créés | Vérifier les montants |
| Transferts bloqués | Vérifier le compte connecté |

### 4. Webhooks
**Où:** Dashboard Stripe → Développeurs → Webhooks

| À vérifier | Action si problème |
|------------|-------------------|
| Tentatives réussies | Tout va bien |
| Tentatives échouées | Vérifier les logs serveur, corriger le problème |

---

# 🚨 GESTION DES PROBLÈMES

## Problème 1: Paiement échoué

### Symptômes:
- Le contributeur dit que son paiement n'est pas passé
- Le paiement apparaît comme "Échoué" sur Stripe

### Diagnostic:
1. Aller sur Dashboard Stripe → Paiements
2. Trouver le paiement
3. Cliquer dessus pour voir les détails
4. Lire le message d'erreur

### Causes fréquentes et solutions:

| Erreur | Cause | Solution |
|--------|-------|----------|
| `card_declined` | Carte refusée par la banque | Demander au contributeur d'utiliser une autre carte |
| `insufficient_funds` | Fonds insuffisants | Demander au contributeur de vérifier son solde |
| `authentication_required` | 3D Secure échoué | Demander au contributeur de réessayer |
| `expired_card` | Carte expirée | Demander une autre carte |

---

## Problème 2: Compte connecté "Limité"

### Symptômes:
- Le porteur ne peut pas recevoir de paiements
- L'état est "Limité" sur Stripe

### Diagnostic:
1. Aller sur Dashboard Stripe → Connect → Comptes connectés
2. Cliquer sur le compte
3. Voir la section "Exigences"

### Solutions:
1. **Informations manquantes**: Contacter le porteur, lui envoyer le lien d'onboarding
2. **Document en attente de vérification**: Attendre (1-2 jours)
3. **Document rejeté**: Demander au porteur de soumettre un autre document

### Renvoyer le lien d'onboarding:
Le porteur peut accéder à son onboarding depuis son profil Fiatope, ou vous pouvez lui envoyer un nouveau lien via la console:
```ruby
user = User.find(USER_ID)
url = user.stripe_account_onboarding_url(
  refresh_url: "https://fiatope.com/stripe/connect/refresh",
  return_url: "https://fiatope.com/stripe/connect/return"
)
puts url  # Envoyer ce lien au porteur
```

---

## Problème 3: Contribution confirmée mais pas de transfert

### Symptômes:
- La contribution est confirmée dans Fiatope
- L'argent n'apparaît pas sur le compte du porteur

### Diagnostic:
1. Vérifier le paiement sur Stripe Dashboard
2. Vérifier si un transfert a été créé
3. Vérifier l'état du compte connecté

### Causes possibles:
1. **Compte connecté non prêt**: Le porteur n'a pas complété son onboarding
2. **Paiement sans Connect**: Le paiement a été fait sans `transfer_data` (bug)
3. **Fonds en attente**: Normal, les fonds sont retenus 7 jours

### Solution si le paiement a été fait sans Connect:
Vous devrez faire un transfert manuel:
```ruby
transfer = Stripe::Transfer.create({
  amount: MONTANT_EN_CENTIMES,
  currency: 'eur',
  destination: 'acct_XXXXXX',  # ID du compte connecté
})
```

---

## Problème 4: Webhook échoué

### Symptômes:
- Contributions pas confirmées automatiquement
- Alertes sur Dashboard Stripe → Webhooks

### Diagnostic:
1. Aller sur Dashboard Stripe → Développeurs → Webhooks
2. Voir les tentatives récentes
3. Cliquer sur une tentative échouée pour voir l'erreur

### Causes fréquentes:

| Erreur | Cause | Solution |
|--------|-------|----------|
| `Connection refused` | Serveur Fiatope down | Vérifier que le serveur tourne |
| `Timeout` | Serveur trop lent | Optimiser le code webhook |
| `500 Internal Server Error` | Bug dans le code | Vérifier les logs serveur |
| `401 Unauthorized` | Mauvaise signature | Vérifier `STRIPE_WEBHOOK_SECRET` |

### Rejouer un webhook:
Sur Dashboard Stripe → Webhooks → cliquer sur l'événement → "Renvoyer"

---

# 💰 COMPRENDRE LES COMMISSIONS

## Calcul détaillé d'une contribution de 100€

```
Contribution:                    100,00 €

Frais Stripe (2.9% + 0.30€):     - 3,20 €
Commission Fiatope (5%):         - 5,00 €
                                 ─────────
Net porteur:                      91,80 €

Ce qui reste à Fiatope:
Commission:                        5,00 €
- Frais Stripe:                  - 3,20 €
                                 ─────────
Net Fiatope:                       1,80 €
```

## Qui paie quoi?

| Acteur | Ce qu'il paie | Ce qu'il reçoit |
|--------|---------------|-----------------|
| Contributeur | 100€ | Reçu de contribution |
| Porteur | Rien (déduit de la contribution) | 91,80€ |
| Fiatope | Frais Stripe | 1,80€ net |
| Stripe | Rien | 3,20€ |

## Modifier la commission

La commission est configurée via la variable d'environnement `PLATFORM_FEE`:
```bash
# Dans votre fichier .env ou configuration serveur
PLATFORM_FEE=5.0  # 5%
```

Pour changer à 8%:
```bash
PLATFORM_FEE=8.0
```

**Note**: Changer la commission ne s'applique qu'aux NOUVEAUX paiements.

---

# 📧 MODÈLES DE COMMUNICATION

## Email au porteur: Compléter l'onboarding

```
Objet: Action requise - Configurez votre compte pour recevoir vos fonds

Bonjour [NOM],

Pour que vous puissiez recevoir les contributions de votre projet "[NOM_PROJET]" sur Fiatope, 
vous devez configurer votre compte de paiement.

C'est simple et ne prend que quelques minutes:

1. Cliquez sur ce lien: [LIEN_ONBOARDING]
2. Remplissez vos informations personnelles
3. Ajoutez vos coordonnées bancaires
4. Téléchargez une pièce d'identité

Une fois ces étapes complétées, vous pourrez recevoir automatiquement 
les contributions sur votre compte bancaire.

Si vous avez des questions, n'hésitez pas à nous contacter.

Cordialement,
L'équipe Fiatope
```

## Email au porteur: Contribution reçue

```
Objet: 🎉 Nouvelle contribution de [MONTANT]€ pour votre projet!

Bonjour [NOM],

Bonne nouvelle! Vous venez de recevoir une contribution de [MONTANT]€ 
pour votre projet "[NOM_PROJET]".

Détails:
- Montant de la contribution: [MONTANT]€
- Commission Fiatope: [COMMISSION]€
- Montant que vous recevrez: [MONTANT_NET]€

L'argent sera automatiquement viré sur votre compte bancaire 
dans les 7 à 14 jours.

Vous pouvez suivre vos contributions dans votre tableau de bord.

Continuez comme ça!

Cordialement,
L'équipe Fiatope
```

## Email au contributeur: Confirmation de paiement

```
Objet: Merci pour votre contribution de [MONTANT]€!

Bonjour [NOM],

Merci pour votre généreuse contribution!

Récapitulatif:
- Projet: [NOM_PROJET]
- Montant: [MONTANT]€
- Date: [DATE]
- Référence: [REFERENCE]

Votre contribution aidera [PORTEUR] à réaliser son projet.

Vous pouvez suivre l'avancement du projet sur Fiatope:
[LIEN_PROJET]

Merci de faire partie de la communauté Fiatope!

Cordialement,
L'équipe Fiatope
```

---

# 🔧 COMMANDES UTILES (Console Rails)

## Vérifier l'état d'un porteur
```ruby
user = User.find(USER_ID)
puts "Compte connecté: #{user.stripe_connect_account_id}"
puts "Onboarding complet: #{user.stripe_onboarding_complete?}"
```

## Vérifier l'état d'un projet
```ruby
project = Project.find(PROJECT_ID)
puts "Stripe activé: #{project.use_stripe?}"
puts "Compte Stripe: #{project.stripe_account_id}"
puts "Prêt: #{project.stripe_ready?}"
```

## Activer Stripe pour un projet
```ruby
project = Project.find(PROJECT_ID)
project.enable_stripe!
```

## Créer un lien d'onboarding
```ruby
user = User.find(USER_ID)
url = user.stripe_account_onboarding_url(
  refresh_url: "https://fiatope.com/stripe/connect/refresh",
  return_url: "https://fiatope.com/stripe/connect/return"
)
puts url
```

## Voir les contributions Stripe d'un projet
```ruby
project = Project.find(PROJECT_ID)
contributions = project.contributions.where(payment_method: 'Stripe')
contributions.each do |c|
  puts "#{c.id}: #{c.value}€ - #{c.state} - #{c.payment_id}"
end
```

---

# ✅ CHECKLIST HEBDOMADAIRE

## Chaque lundi matin:

- [ ] Vérifier les comptes connectés "Limités" et relancer les porteurs
- [ ] Vérifier les webhooks échoués de la semaine
- [ ] Vérifier les paiements échoués et contacter les contributeurs si besoin
- [ ] Vérifier le volume des commissions perçues

## Chaque fin de mois:

- [ ] Exporter les statistiques de paiement
- [ ] Vérifier les virements effectués aux porteurs
- [ ] Réconcilier les commissions Fiatope
- [ ] Archiver les rapports

---

# 🧪 RÉSULTATS DES TESTS (18/01/2026)

## Tests effectués et validés:

| Phase | Description | Statut |
|-------|-------------|--------|
| 1 | Création utilisateurs test | ✅ |
| 2 | Création comptes Stripe Connect | ✅ |
| 3 | Onboarding porteurs | ✅ |
| 4 | Création projets test | ✅ |
| 5 | Contributions via Stripe Checkout | ✅ |
| 6 | Récupération des charge_id | ✅ |
| 7 | Transfert campagne réussie | ✅ |
| 8 | Remboursement campagne échouée | ✅ |
| 9 | Vérification commissions | ✅ |

## Données de test:

### Campagne Réussie
- **Projet:** Test Stripe - Campagne Réussie (ID: 7)
- **Porteur:** Pierre Porteur Succès (acct_1SqXU1GsuyeZQUNK)
- **Contribution:** 150€ de Jean Contributeur
- **Transfer ID:** tr_1Sr4KaGU9iw1wSnAoWQjWKRA
- **Montant transféré:** 142.50€ (après 5% commission)

### Campagne Échouée
- **Projet:** Test Stripe - Campagne Échouée (ID: 8)
- **Porteur:** Marie Porteur Échec (acct_1SqXezGzbyh1rPp6)
- **Contribution:** 50€ de Jean Contributeur
- **Statut:** Remboursée via Stripe

## Structure des frais:

| Élément | Calcul | Exemple (150€) |
|---------|--------|----------------|
| Contribution brute | - | 150.00€ |
| Frais Stripe (~3.4% + 0.25€) | - | 5.13€ |
| Net plateforme | - | 144.87€ |
| Commission Fiatope (5% du brut) | 150 × 5% | 7.50€ |
| Montant transféré au porteur | 150 - 7.50 | 142.50€ |
| **Commission nette Fiatope** | 7.50 - 5.13 | **2.37€** |

---

**Document créé pour Fiatope - Guide opérationnel Stripe Connect**
**Dernière mise à jour:** 18/01/2026
