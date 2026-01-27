# 🚀 GUIDE DE DÉPLOIEMENT STRIPE EN PRODUCTION

## ✅ Ce qui est prêt (fait par Cascade)

L'intégration Stripe est **complète et commitée** dans la branche `fix-rewards-minimal`:
- ✅ Gem `neighborly-stripe` avec tous les controllers
- ✅ PaymentsController (création session, success, cancel)
- ✅ WebhooksController (confirmation backup)
- ✅ ConnectController (onboarding porteurs de projet)
- ✅ Templates email de confirmation (FR + EN)
- ✅ Page de succès professionnelle et centrée
- ✅ Notifications automatiques après paiement
- ✅ Documentation technique complète

---

## 📋 ACTIONS MANUELLES À EFFECTUER

### 1. PUSH DE LA BRANCHE

```bash
# Vérifier que vous êtes sur la bonne branche
git branch --show-current
# Doit afficher: fix-rewards-minimal

# Pousser vers le dépôt distant
git push origin fix-rewards-minimal
```

---

### 2. CONFIGURATION STRIPE DASHBOARD

#### 2.1 Obtenir les clés API de production

1. Connectez-vous à [Stripe Dashboard](https://dashboard.stripe.com)
2. Passez en mode **Live** (pas Test) en haut à droite
3. Allez dans **Developers > API keys**
4. Copiez:
   - **Publishable key** (commence par `pk_live_`)
   - **Secret key** (commence par `sk_live_`)

#### 2.2 Configurer le Webhook

1. Dans Stripe Dashboard, allez dans **Developers > Webhooks**
2. Cliquez sur **Add endpoint**
3. Configurez:
   - **Endpoint URL**: `https://fiatope.com/stripe/webhooks`
   - **Events to send** (sélectionnez):
     - `checkout.session.completed`
     - `payment_intent.succeeded`
     - `payment_intent.payment_failed`
     - `charge.refunded`
     - `account.updated`
4. Cliquez sur **Add endpoint**
5. Copiez le **Signing secret** (commence par `whsec_`)

---

### 3. VARIABLES D'ENVIRONNEMENT EN PRODUCTION

Ajoutez ces variables dans votre fichier `.env` de production ou dans la configuration de votre hébergeur:

```bash
# Clés Stripe PRODUCTION (à remplacer par vos vraies clés)
STRIPE_SECRET_KEY=sk_live_VOTRE_CLE_SECRETE_ICI
STRIPE_PUBLISHABLE_KEY=pk_live_VOTRE_CLE_PUBLIQUE_ICI
STRIPE_WEBHOOK_SECRET=whsec_VOTRE_SECRET_WEBHOOK_ICI

# Commission plateforme (5% par défaut)
PLATFORM_FEE=5.0
```

**⚠️ IMPORTANT**: Ne jamais commiter les clés live dans le code!

---

### 4. MIGRATIONS BASE DE DONNÉES

Exécutez les migrations pour ajouter les colonnes Stripe:

```bash
# En production
RAILS_ENV=production bundle exec rake db:migrate
```

Les migrations ajouteront:
- `users.stripe_customer_id`
- `users.stripe_connect_account_id`
- `users.stripe_onboarding_complete`
- `projects.stripe_account_id`
- `projects.use_stripe`
- Table `stripe_orders` (optionnelle)

---

### 5. ACTIVER STRIPE POUR UN PROJET

Pour qu'un projet puisse accepter les paiements Stripe:

```ruby
# Dans la console Rails
project = Project.find_by(permalink: 'nom-du-projet')
project.update(use_stripe: true)
```

Ou via l'interface admin si disponible.

---

### 6. TEST EN PRODUCTION (avec petit montant)

Avant d'annoncer aux utilisateurs:

1. Activez Stripe sur un projet test
2. Faites une contribution de **1€** avec une vraie carte
3. Vérifiez:
   - [ ] Redirection vers Stripe Checkout
   - [ ] Paiement accepté
   - [ ] Redirection vers page de succès
   - [ ] Contribution visible dans la base
   - [ ] Email de confirmation reçu
   - [ ] Statistiques projet mises à jour

---

## 🔧 CONFIGURATION STRIPE CONNECT (OPTIONNEL)

Si vous voulez que les porteurs de projet reçoivent directement les fonds:

### 6.1 Activer Stripe Connect

1. Dans Stripe Dashboard > **Settings > Connect**
2. Configurez les paramètres de votre plateforme
3. Acceptez les conditions d'utilisation de Connect

### 6.2 Onboarding d'un porteur de projet

Le porteur de projet doit:
1. Accéder à `/stripe/connect/create` sur votre plateforme
2. Suivre le processus d'onboarding Stripe
3. Fournir ses informations bancaires

Une fois terminé, les paiements seront automatiquement répartis:
- Porteur de projet: montant - commission
- Plateforme Fiatope: commission (5% par défaut)

---

## 📊 VÉRIFICATION POST-DÉPLOIEMENT

### Checklist finale

- [ ] Variables d'environnement configurées
- [ ] Migrations exécutées
- [ ] Webhook actif et fonctionnel
- [ ] Test de paiement réussi
- [ ] Emails de confirmation envoyés
- [ ] Logs sans erreurs

### Commandes utiles

```bash
# Vérifier les contributions Stripe
rails console
> Contribution.where(payment_method: 'Stripe').count

# Vérifier un projet Stripe
> Project.find_by(permalink: 'tech').use_stripe?

# Vérifier les logs Stripe
tail -f log/production.log | grep -i stripe
```

---

## 🆘 SUPPORT

En cas de problème:
1. Vérifiez les logs Rails pour les erreurs
2. Vérifiez les webhooks dans Stripe Dashboard (section Events)
3. Consultez la documentation dans `docs/STRIPE_CROWDFUNDING_DOCUMENTATION.md`

---

## 📝 RÉSUMÉ DES FICHIERS CRÉÉS

```
lib/neighborly-stripe-0.1.0/           # Gem Stripe complète
├── app/controllers/neighborly/stripe/
│   ├── payments_controller.rb         # Paiements Checkout
│   ├── webhooks_controller.rb         # Webhooks
│   └── connect_controller.rb          # Stripe Connect
├── app/models/neighborly/stripe/
│   ├── user.rb                        # Extensions User
│   ├── project.rb                     # Extensions Project
│   └── order.rb                       # Ordres Stripe
├── app/views/neighborly/stripe/
│   └── payments/success.html.erb      # Page succès
├── config/routes.rb                   # Routes Stripe
└── db/migrate/                        # Migrations

app/views/notifications_mailer/
├── stripe_payment_confirmed.fr.html.slim
├── stripe_payment_confirmed.en.html.slim
└── subjects/stripe_payment_confirmed.*.slim

config/initializers/stripe.rb          # Configuration
docs/STRIPE_CROWDFUNDING_DOCUMENTATION.md
```

---

**🎉 L'intégration Stripe est prête à être utilisée en production!**
