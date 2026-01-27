# Documentation Complète - Intégration Stripe Crowdfunding Fiatope

## 📋 Résumé Exécutif

Cette documentation décrit l'intégration complète de Stripe comme méthode de paiement pour la plateforme de crowdfunding Fiatope. L'intégration permet aux contributeurs de payer par carte bancaire via Stripe Checkout, avec confirmation automatique des contributions et mise à jour en temps réel des statistiques du projet.

---

## 🏗️ Architecture du Système

### Composants Principaux

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FLUX DE PAIEMENT STRIPE                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. INITIATION                                                       │
│  ┌──────────────┐    ┌───────────────────┐    ┌──────────────────┐  │
│  │ Contributeur │───▶│ Page Contribution │───▶│ Choix Stripe     │  │
│  └──────────────┘    └───────────────────┘    └──────────────────┘  │
│                                                        │             │
│  2. CRÉATION SESSION STRIPE                            ▼             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ PaymentsController#new                                        │   │
│  │ - Vérifie projet.use_stripe?                                 │   │
│  │ - Vérifie Connect account ready                               │   │
│  │ - Crée Stripe::Checkout::Session avec metadata               │   │
│  │ - Redirect vers Stripe Checkout                               │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                        │             │
│  3. PAIEMENT STRIPE CHECKOUT                           ▼             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Interface Stripe Checkout (hébergée par Stripe)              │   │
│  │ - Saisie carte bancaire                                       │   │
│  │ - 3D Secure si nécessaire                                    │   │
│  │ - Validation du paiement                                      │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                        │             │
│  4. CONFIRMATION & ENREGISTREMENT                      ▼             │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ PaymentsController#success                                    │   │
│  │ - Récupère session Stripe avec session_id                    │   │
│  │ - Vérifie payment_status == 'paid'                           │   │
│  │ - Crée/Met à jour Contribution                                │   │
│  │ - contribution.confirm! → state: 'confirmed'                 │   │
│  │ - Déclenche after_transition: update_resource_project_total  │   │
│  │ - Affiche page succès                                         │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Fichiers Clés

| Fichier | Rôle |
|---------|------|
| `lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/payments_controller.rb` | Controller principal: initiation paiement, success, cancel |
| `lib/neighborly-stripe-0.1.0/app/views/neighborly/stripe/payments/success.html.erb` | Page de succès après paiement |
| `lib/neighborly-stripe-0.1.0/app/controllers/neighborly/stripe/webhooks_controller.rb` | Webhooks Stripe (backup) |
| `app/models/contribution.rb` | Modèle Contribution avec state machine |
| `app/models/concerns/shared/payment_state_machine_handler.rb` | Machine d'états des contributions |

---

## 🔄 Flux Détaillé du Paiement

### Étape 1: Initiation du Paiement

**Action:** `PaymentsController#new`

```ruby
# 1. Récupération du projet et contribution
@project = ::Project.find(params[:project_id])
@contribution = @project.contributions.find(params[:contribution_id])

# 2. Vérification Stripe activé
unless @project.use_stripe?
  redirect_to project_path # Projet non éligible
end

# 3. Vérification Connect account (optionnel)
connect_ready = false
if @project.stripe_account_id.present?
  account = ::Stripe::Account.retrieve(@project.stripe_account_id)
  connect_ready = account.charges_enabled && account.capabilities&.transfers == 'active'
end

# 4. Création session Stripe Checkout
session = ::Stripe::Checkout::Session.create({
  payment_method_types: ['card'],
  line_items: [{
    price_data: {
      currency: 'eur',
      product_data: { name: @project.name },
      unit_amount: amount_cents
    },
    quantity: 1
  }],
  mode: 'payment',
  success_url: "#{base_url}/stripe/projects/#{@project.id}/payments/success?session_id={CHECKOUT_SESSION_ID}",
  cancel_url: "#{base_url}/stripe/projects/#{@project.id}/payments/cancel",
  metadata: {
    project_id: @project.id,
    user_id: current_user.id,
    contribution_id: @contribution&.id
  }
})

# 5. Redirection vers Stripe Checkout
redirect_to session.url
```

### Étape 2: Paiement sur Stripe Checkout

L'utilisateur est redirigé vers l'interface Stripe Checkout où il saisit:
- Numéro de carte
- Date d'expiration
- CVC
- (3D Secure si requis par la banque)

### Étape 3: Confirmation et Enregistrement

**Action:** `PaymentsController#success`

```ruby
# 1. Récupération de la session Stripe
session = ::Stripe::Checkout::Session.retrieve(session_id)

if session.payment_status == 'paid'
  # 2. Extraction des métadonnées
  user_id = session.metadata['user_id']
  contribution_id = session.metadata['contribution_id']
  amount = session.amount_total / 100.0
  
  # 3. Création ou mise à jour de la contribution
  if contribution_id.present?
    @contribution = Contribution.find(contribution_id)
    @contribution.update(
      payment_method: 'Stripe',
      payment_id: session.payment_intent,
      confirmed_at: Time.current
    )
  else
    @contribution = Contribution.create!(
      project: @project,
      user: user,
      value: amount,
      payment_method: 'Stripe',
      payment_id: session.payment_intent,
      confirmed_at: Time.current
    )
  end
  
  # 4. Confirmation de la contribution
  @contribution.confirm!  # Transition: pending → confirmed
  
  # 5. Mise à jour automatique du projet (via state machine)
  # after_transition déclenche: update_resource_project_total
end
```

---

## 📊 Machine d'États des Contributions

```
                    ┌─────────────────┐
                    │    pending      │ (état initial)
                    └────────┬────────┘
                             │
                    wait_confirmation
                             │
                             ▼
                    ┌─────────────────┐
                    │waiting_confirmation│
                    └────────┬────────┘
                             │
                         confirm
                             │
                             ▼
                    ┌─────────────────┐
         ┌─────────│   confirmed     │─────────┐
         │         └─────────────────┘         │
         │                                     │
    request_refund                          cancel
         │                                     │
         ▼                                     ▼
┌─────────────────┐                   ┌─────────────────┐
│requested_refund │                   │    canceled     │
└────────┬────────┘                   └─────────────────┘
         │
       refund
         │
         ▼
┌─────────────────┐
│    refunded     │
└─────────────────┘
```

### Événements de Transition

| Événement | De → Vers | Action |
|-----------|-----------|--------|
| `confirm` | all → confirmed | Déclenche `update_resource_project_total` |
| `cancel` | all → canceled | - |
| `request_refund` | confirmed → requested_refund | Si credits >= value |
| `refund` | requested_refund → refunded | Déclenche `mangopay_refund` |

---

## 👥 Acteurs du Système

### 1. Contributeur (User)
- Navigue sur le projet
- Choisit un montant de contribution
- Sélectionne Stripe comme moyen de paiement
- Effectue le paiement via Stripe Checkout
- Reçoit confirmation et peut suivre le projet

### 2. Porteur de Projet (Project Owner)
- Configure son compte Stripe Connect (optionnel)
- Reçoit les fonds sur son compte Stripe Connect
- Peut voir les contributions dans son dashboard

### 3. Plateforme Fiatope
- Gère la session Stripe Checkout
- Enregistre les contributions dans la base de données
- Calcule et prélève les frais de plateforme
- Met à jour les statistiques du projet

### 4. Stripe
- Héberge l'interface de paiement sécurisée
- Traite les paiements par carte
- Gère la conformité PCI-DSS
- Envoie les webhooks de confirmation (backup)

---

## 💰 Flux Financier

### Mode Direct (Connect non configuré)
```
Contributeur ──[100€]──▶ Compte Stripe Fiatope
```

### Mode Connect (Marketplace)
```
Contributeur ──[100€]──▶ Stripe ──▶ Porteur de Projet (95€)
                              └──▶ Plateforme Fiatope (5€ commission)
```

### Calcul des Frais
```ruby
# Frais Stripe (cartes européennes)
stripe_fee = amount * 0.014 + 0.25  # 1.4% + 0.25€

# Commission plateforme (configurable par projet)
platform_fee = project.platform_fee_amount(amount_cents)
```

---

## 🔐 Sécurité

### Points de Sécurité Implémentés

1. **Vérification du paiement côté serveur**
   - Le `session_id` est vérifié via l'API Stripe
   - Impossible de simuler un paiement réussi

2. **Métadonnées signées**
   - Les IDs projet/user/contribution sont stockés dans les metadata Stripe
   - Récupérés depuis Stripe, pas depuis l'URL

3. **Webhooks (backup)**
   - Signature vérifiée avec `STRIPE_WEBHOOK_SECRET`
   - Confirmation redondante des paiements

4. **Protection CSRF**
   - Désactivé uniquement pour les webhooks
   - Actif pour toutes les autres actions

---

## 🧪 Tests et Vérification

### Carte de Test Stripe
```
Numéro: 4242 4242 4242 4242
Date: Toute date future
CVC: Tout code à 3 chiffres
```

### Script de Vérification
```bash
# Tester la création de contribution
ruby TEST_CONTRIBUTION_STRIPE.rb

# Vérifier les paiements existants
ruby VERIFY_EXISTING_STRIPE_PAYMENTS.rb
```

### Checklist de Validation
- [ ] Bouton Stripe visible sur la page de contribution
- [ ] Redirection vers Stripe Checkout fonctionne
- [ ] Paiement avec carte test réussit
- [ ] Redirection vers page succès
- [ ] Contribution créée dans la base (state: confirmed)
- [ ] Statistiques projet mises à jour (pledged, contributors)
- [ ] Email de confirmation envoyé (si configuré)

---

## ⚙️ Configuration Production

### Variables d'Environnement Requises
```bash
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_PUBLISHABLE_KEY=pk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx  # Pour les webhooks
```

### Webhook Stripe à Configurer
URL: `https://fiatope.com/stripe/webhooks`

Événements à écouter:
- `checkout.session.completed`
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `charge.refunded`

---

## 📈 Métriques à Surveiller

| Métrique | Description | Alerte si |
|----------|-------------|-----------|
| Taux de conversion | Paiements réussis / Sessions créées | < 70% |
| Contributions pending | Contributions non confirmées | > 0 après 24h |
| Erreurs Stripe | Exceptions dans les logs | Toute erreur |

---

## 🔧 Dépannage

### Contribution non enregistrée
1. Vérifier les logs Rails pour erreurs
2. Vérifier que `session.payment_status == 'paid'`
3. Vérifier les metadata dans la session Stripe

### Statistiques projet non mises à jour
1. Vérifier que `contribution.state == 'confirmed'`
2. Vérifier le callback `after_transition`
3. Exécuter manuellement: `project.reload.pledged`

### Page succès affiche erreur
1. Vérifier que `@project` existe
2. Vérifier les helpers avec préfixe `main_app.`
3. Vérifier les commentaires ERB (pas HTML comments)

---

## 📝 Modifications Effectuées

### 1. PaymentsController#success (CRITIQUE)
**Avant:** Affichait seulement un message de succès
**Après:** Crée/confirme la contribution dans la base de données

### 2. Page de Succès
**Avant:** Design basique
**Après:** Design professionnel avec récapitulatif, impact, partage social

### 3. Gestion des États
**Avant:** Utilisait `may_confirm?` (incorrect)
**Après:** Vérifie `state != 'confirmed'` avec gestion d'erreurs

### 4. Notifications Email (NOUVEAU - 17/12/2025)
**Ajouté:**
- Template `stripe_payment_confirmed.fr.html.slim` - Email au contributeur (FR)
- Template `stripe_payment_confirmed.en.html.slim` - Email au contributeur (EN)
- Sujets d'email correspondants
- Méthode `send_stripe_notifications()` dans PaymentsController
- Notification au porteur de projet via `project_owner_contribution_confirmed`

### 5. Affichage Progress (NOUVEAU - 17/12/2025)
**Problème:** Progress affiché 0% même avec des contributions (0.61% arrondi à 0)
**Solution:** Calcul avec décimales dans la page succès:
```erb
<% real_progress = @project.goal.to_f > 0 ? (@project.pledged.to_f / @project.goal.to_f * 100) : 0 %>
<%= number_with_precision(real_progress, precision: 1, strip_insignificant_zeros: true) %>%
```

### 6. WebhooksController Corrigé (NOUVEAU - 17/12/2025)
**Avant:** Utilisait `may_confirm?`, `may_cancel?`, `may_refund?` (non existants)
**Après:** Vérification d'état directe avec try/rescue pour robustesse

### 7. PaymentObserver Mis à Jour (NOUVEAU - 17/12/2025)
**Modification:** Exclusion de Stripe des notifications génériques (comme Orange Money)
```ruby
unless resource.payment_method.in?(["Orange Money", "Stripe"])
  # Notifications génériques
end
```
**Raison:** Éviter les doublons - Stripe a ses propres templates spécifiques

---

## 📧 Système de Notifications Email

### Flux de Notification Stripe

```
Paiement Stripe réussi
        │
        ▼
PaymentsController#success
        │
        ├──▶ contribution.confirm!
        │
        └──▶ send_stripe_notifications()
                    │
                    ├──▶ Contributeur: :stripe_payment_confirmed
                    │    (Template personnalisé avec détails paiement)
                    │
                    └──▶ Porteur projet: :project_owner_contribution_confirmed
                         (Template existant réutilisé)
```

### Comparaison avec Autres Méthodes de Paiement

| Méthode | Email Contributeur | Email Porteur | Observateur |
|---------|-------------------|---------------|-------------|
| **Stripe** | stripe_payment_confirmed | project_owner_contribution_confirmed | Exclu |
| **Orange Money** | orange_money_payment_confirmed | project_owner_contribution_confirmed | Exclu |
| **MangoPay/Autres** | payment_confirmed | project_owner_contribution_confirmed | Via PaymentObserver |

---

## ✅ Conclusion

L'intégration Stripe est maintenant **pleinement fonctionnelle** et respecte l'essence crowdfunding de la plateforme:

1. **Paiement sécurisé** via Stripe Checkout
2. **Contribution enregistrée** automatiquement après paiement
3. **Statistiques projet** mises à jour en temps réel
4. **Page de succès** professionnelle et engageante
5. **Traçabilité complète** avec payment_id Stripe

Le système est prêt pour la production après configuration des clés API live et du webhook.
