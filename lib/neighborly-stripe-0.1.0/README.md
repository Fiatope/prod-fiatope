# Neighborly Stripe Connect Engine

Engine Rails pour l'intégration de Stripe Connect dans Fiatope/Kwendoo.

## Installation

L'engine est déjà configuré dans le Gemfile principal. Les migrations sont automatiquement chargées.

## Configuration

Variables d'environnement requises dans `.env`:

```bash
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...  # À configurer après création du webhook
```

## Fonctionnalités

### 1. Onboarding des porteurs de projet (Stripe Connect)

Chaque porteur de projet doit créer un compte Stripe Connect pour recevoir des paiements.

**URL**: `/stripe/connect/create`

### 2. Paiements contributeurs

Les contributeurs paient via Stripe Checkout avec transfert automatique vers le compte du porteur.

**URL**: `/stripe/projects/:project_id/payments/new`

### 3. Webhooks Stripe

Endpoint pour recevoir les notifications Stripe (paiements, remboursements, etc.)

**URL**: `/stripe/webhooks` (POST)

## Utilisation

### Activer Stripe sur un projet

```ruby
project = Project.find(id)
project.enable_stripe!  # Crée le compte Connect et active Stripe
```

### Vérifier si un projet peut recevoir des paiements Stripe

```ruby
project.stripe_ready?  # true si compte Connect configuré et vérifié
```

### Traiter un paiement

Le paiement se fait via Stripe Checkout. L'utilisateur est redirigé vers Stripe, puis revient sur le site.

### Webhooks à configurer dans Stripe Dashboard

1. Aller sur https://dashboard.stripe.com/webhooks
2. Créer un endpoint: `https://votre-domaine.com/stripe/webhooks`
3. Sélectionner ces événements:
   - `checkout.session.completed`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `charge.refunded`
   - `account.updated`
   - `transfer.created`
4. Copier le signing secret dans `.env` → `STRIPE_WEBHOOK_SECRET`

## Tests

### Numéros de carte de test Stripe

- **Succès**: `4242 4242 4242 4242`
- **Décliné**: `4000 0000 0000 0002`
- **3D Secure**: `4000 0027 6000 3184`
- **Date**: n'importe quelle date future
- **CVC**: n'importe quels 3 chiffres

### Tester les webhooks en local

```bash
# Installer Stripe CLI
stripe listen --forward-to localhost:3001/stripe/webhooks

# Tester un événement spécifique
stripe trigger payment_intent.succeeded
```

## Architecture

### Models

- `Neighborly::Stripe::User` - Concern ajouté au model User
- `Neighborly::Stripe::Project` - Concern ajouté au model Project  
- `Neighborly::Stripe::Contribution` - Concern ajouté au model Contribution
- `Neighborly::Stripe::Order` - Model pour les commandes Stripe

### Controllers

- `Neighborly::Stripe::ConnectController` - Onboarding Stripe Connect
- `Neighborly::Stripe::PaymentsController` - Checkout et paiements
- `Neighborly::Stripe::WebhooksController` - Réception événements Stripe

## Flux de paiement

1. Contributeur clique "Contribuer" sur un projet
2. Redirection vers Stripe Checkout
3. Paiement effectué sur Stripe
4. Stripe envoie webhook `checkout.session.completed`
5. Création de la Contribution et du StripeOrder
6. Webhook `payment_intent.succeeded` confirme le paiement
7. Contribution marquée comme `confirmed`
8. Argent transféré automatiquement vers le compte Connect du porteur (moins frais plateforme)

## Migration depuis Mangopay

Les deux systèmes coexistent. Pour basculer un projet sur Stripe:

```ruby
project.enable_stripe!
```

Les anciens projets restent sur Mangopay, les nouveaux peuvent utiliser Stripe.

## Support

En cas de problème, vérifier:
1. Les clés API Stripe sont correctes
2. Le webhook secret est configuré
3. Les logs Rails pour les erreurs détaillées
4. Le dashboard Stripe pour l'état des paiements
