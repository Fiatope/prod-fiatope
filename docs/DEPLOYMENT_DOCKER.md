# 🚀 Guide de Déploiement Docker - Fiatope

## Prérequis

- Docker 20.10+
- Docker Compose 2.0+
- Compte Stripe Connect configuré

## Variables d'Environnement Obligatoires

### Stripe Connect (CRITIQUE)

```bash
# Clés API Stripe (depuis dashboard.stripe.com)
STRIPE_SECRET_KEY=sk_live_xxx      # ou sk_test_xxx pour test
STRIPE_PUBLISHABLE_KEY=pk_live_xxx # ou pk_test_xxx pour test
STRIPE_WEBHOOK_SECRET=whsec_xxx    # Pour valider les webhooks
```

### Base de Données

```bash
POSTGRES_PASSWORD=votre_mot_de_passe_securise
DATABASE_URL=postgresql://fiatope:password@db:5432/fiatope_production
```

### Rails

```bash
SECRET_KEY_BASE=$(openssl rand -hex 64)
RAILS_ENV=production
```

## Déploiement Rapide

### 1. Créer le fichier `.env`

```bash
cp .env.example .env
# Éditer .env avec vos valeurs réelles
```

### 2. Lancer les services

```bash
docker-compose up -d
```

### 3. Vérifier les logs

```bash
docker-compose logs -f web
```

### 4. Exécuter les migrations (automatique au démarrage)

Les migrations sont exécutées automatiquement par le script d'entrée Docker.
Pour les forcer manuellement:

```bash
docker-compose exec web bin/rails db:migrate
```

### 5. Synchroniser les comptes Stripe existants

```bash
docker-compose exec web bin/rails stripe:sync_all_projects
```

### 6. Tester l'intégration Stripe

```bash
docker-compose exec web bin/rails stripe:test_integration
docker-compose exec web bin/rails stripe:test_admin_scenarios
```

## Configuration Stripe Connect

### Webhooks à configurer dans Stripe Dashboard

URL: `https://votre-domaine.com/stripe/webhooks`

Événements à activer:
- `account.updated` - Mise à jour du statut onboarding
- `payment_intent.succeeded` - Paiement réussi
- `payment_intent.payment_failed` - Paiement échoué
- `charge.refunded` - Remboursement effectué
- `transfer.created` - Transfert créé

### Vérification du compte Connect

```ruby
# Console Rails
user = User.find_by(email: "porteur@example.com")
user.stripe_connect_account_id  # => "acct_xxx"
user.stripe_onboarding_complete? # => true/false
```

## Commandes Utiles

### Logs

```bash
# Logs web
docker-compose logs -f web

# Logs worker (Sidekiq)
docker-compose logs -f worker

# Tous les logs
docker-compose logs -f
```

### Console Rails

```bash
docker-compose exec web bin/rails console
```

### Tests Stripe

```bash
# Test d'intégration complet
docker-compose exec web bin/rails stripe:test_integration

# Test des scénarios admin
docker-compose exec web bin/rails stripe:test_admin_scenarios

# Synchroniser les projets
docker-compose exec web bin/rails stripe:sync_all_projects
```

### Rebuild

```bash
docker-compose build --no-cache
docker-compose up -d
```

## Troubleshooting

### Erreur "Stripe account not found"

Le porteur n'a pas encore créé son compte Stripe Connect.

**Solution:**
1. Aller dans l'admin
2. Cliquer sur "Lien Onboarding Stripe" pour le projet
3. Envoyer le lien au porteur

### Erreur "Insufficient funds"

Le transfert utilise `source_transaction` pour éviter ce problème.
Vérifier que le `charge_id` est bien enregistré sur la contribution.

### Bouton transfert désactivé

L'onboarding Stripe du porteur n'est pas complet.

**Vérification:**
```ruby
project.user.stripe_onboarding_complete? # Doit retourner true
```

### Remboursement impossible après transfert

C'est le comportement attendu! Une fois les fonds transférés au porteur,
il faut contacter le porteur directement pour un remboursement.

## Architecture Docker

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     web     │────▶│     db      │     │    redis    │
│  (Rails)    │     │ (Postgres)  │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       ▲
       │                                       │
       └───────────────────────────────────────┘
                         │
                  ┌─────────────┐
                  │   worker    │
                  │ (Sidekiq)   │
                  └─────────────┘
```

## Monitoring

### Santé des services

```bash
docker-compose ps
```

### Métriques Sidekiq

Accessible via: `https://votre-domaine.com/sidekiq` (admin uniquement)

## Sauvegarde

### Base de données

```bash
docker-compose exec db pg_dump -U fiatope fiatope_production > backup.sql
```

### Restauration

```bash
cat backup.sql | docker-compose exec -T db psql -U fiatope fiatope_production
```
