# AUDIT COMPLET - Intégration Stripe Connect Fiatope

> Document généré le 26/01/2026
> Version: 2.0 - Post-corrections synchronisation

---

## 1. ARCHITECTURE STRIPE CONNECT

### 1.1 Type d'intégration
- **Modèle**: Separate Charges and Transfers
- **Raison**: Permet de collecter les paiements sur le compte plateforme Fiatope, puis de transférer aux porteurs de projet après validation

### 1.2 Flux de données
```
Contributeur -> Stripe Checkout -> Plateforme Fiatope -> Transfert -> Compte Porteur
```

### 1.3 Fichiers clés
| Fichier | Rôle |
|---------|------|
| `lib/neighborly-stripe-0.1.0/` | Engine Stripe principal |
| `app/models/neighborly/stripe/user.rb` | Extension User pour Stripe Connect |
| `app/models/neighborly/stripe/project.rb` | Extension Project pour Stripe |
| `app/controllers/neighborly/stripe/connect_controller.rb` | Onboarding Connect |
| `app/controllers/neighborly/stripe/payments_controller.rb` | Checkout Sessions |
| `app/controllers/neighborly/stripe/webhooks_controller.rb` | Événements Stripe |
| `app/services/neighborly/stripe/campaign_settlement.rb` | Transferts/Remboursements |
| `app/services/neighborly/stripe/sync_service.rb` | Synchronisation complète |

---

## 2. SCÉNARIOS DE TEST

### 2.1 Création compte Stripe Connect (Porteur)

**Prérequis**: Utilisateur authentifié avec au moins un projet

**Étapes**:
1. Aller sur `/users/{id}/edit` -> onglet Settings
2. Section "Stripe Connect" visible
3. Cliquer "Créer mon compte Stripe"
4. Redirection vers Stripe Onboarding
5. Compléter les informations requises
6. Retour sur Fiatope

**Vérifications**:
- [ ] `user.stripe_connect_account_id` est défini
- [ ] `user.stripe_onboarding_complete` = true (si terminé)
- [ ] Tous les projets du user ont `stripe_account_id` synchronisé
- [ ] Tous les projets ont `use_stripe` = true

**Commande de vérification**:
```ruby
user = User.find(ID)
puts "Compte: #{user.stripe_connect_account_id}"
puts "Onboarding: #{user.stripe_onboarding_complete}"
user.projects.each { |p| puts "#{p.name}: #{p.stripe_account_id} (use_stripe: #{p.use_stripe})" }
```

### 2.2 Synchronisation User -> Projets

**Scénario A**: Porteur crée compte APRÈS avoir créé ses projets
1. Créer un projet sans compte Stripe
2. Créer le compte Stripe via Settings
3. Vérifier que le projet est automatiquement synchronisé

**Scénario B**: Admin force la synchronisation
1. Dans admin `/admin/projects`
2. Trouver un projet avec label "🔗 Synchroniser"
3. Cliquer sur le label
4. Vérifier le flash de succès

**Scénario C**: Webhook account.updated
1. Simuler un webhook `account.updated` avec Stripe CLI
2. Vérifier que tous les projets sont synchronisés

### 2.3 Paiement Contributeur

**Prérequis**: Projet avec Stripe activé et onboarding complet

**Étapes**:
1. Page projet -> Contribuer
2. Sélectionner montant et/ou récompense
3. Redirection vers Stripe Checkout
4. Payer avec carte test (4242 4242 4242 4242)
5. Retour sur page de succès

**Vérifications**:
- [ ] Contribution créée avec `payment_method: 'Stripe'`
- [ ] `payment_id` contient le PaymentIntent ID
- [ ] État = 'confirmed' après webhook
- [ ] StripeOrder créé avec tous les IDs

**Cartes de test**:
| Carte | Scénario |
|-------|----------|
| 4242 4242 4242 4242 | Succès |
| 4000 0000 0000 0002 | Refusée |
| 4000 0000 0000 9995 | Fonds insuffisants |
| 4000 0025 0000 3155 | 3D Secure requis |

### 2.4 Transfert Admin

**Prérequis**: Contributions confirmées, porteur onboarding complet

**Étapes**:
1. Admin `/admin/projects`
2. Trouver projet avec "💰 Transférer"
3. Cliquer -> Modal de confirmation
4. Vérifier les montants (brut, frais, net)
5. Confirmer le transfert

**Vérifications**:
- [ ] `project.stripe_settlement_type` = 'transferred'
- [ ] `project.stripe_transfer_id` défini
- [ ] Contributions marquées `stripe_transferred: true`
- [ ] Fonds visibles sur Dashboard Stripe du porteur

### 2.5 Remboursement Admin

**Prérequis**: Contributions confirmées, PAS encore transférées

**Étapes**:
1. Admin `/admin/projects`
2. Trouver projet avec "↩️ Rembourser"
3. Cliquer -> Modal de confirmation
4. Confirmer le remboursement

**Vérifications**:
- [ ] `project.stripe_settlement_type` = 'refunded'
- [ ] Contributions marquées `stripe_refunded: true`
- [ ] Contributeurs reçoivent remboursement (5-10 jours)
- [ ] Option transfert désactivée après remboursement

### 2.6 Webhooks

**Événements gérés**:
| Événement | Handler | Action |
|-----------|---------|--------|
| checkout.session.completed | handle_checkout_completed | Crée/met à jour contribution |
| checkout.session.async_payment_succeeded | handle_async_payment_succeeded | Confirme paiement différé |
| checkout.session.async_payment_failed | handle_async_payment_failed | Annule paiement différé |
| payment_intent.succeeded | handle_payment_succeeded | Confirme contribution |
| payment_intent.payment_failed | handle_payment_failed | Annule contribution |
| charge.refunded | handle_charge_refunded | Marque remboursé |
| charge.dispute.created | handle_dispute_created | Alerte admin |
| account.updated | handle_account_updated | Sync projets |
| transfer.created | handle_transfer_created | Log transfert |
| transfer.reversed | handle_transfer_reversed | Annule transfert |

**Test avec Stripe CLI**:
```bash
# Écouter les webhooks en local
stripe listen --forward-to localhost:3000/stripe/webhooks

# Déclencher un événement de test
stripe trigger checkout.session.completed
stripe trigger account.updated
```

---

## 3. VÉRIFICATIONS DE SÉCURITÉ

### 3.1 Variables d'environnement requises
```env
STRIPE_SECRET_KEY=sk_live_xxx        # Clé secrète API
STRIPE_PUBLISHABLE_KEY=pk_live_xxx   # Clé publique
STRIPE_WEBHOOK_SECRET=whsec_xxx      # Secret webhook
```

### 3.2 Vérification signature webhook
- Ligne 33-48 de `webhooks_controller.rb`
- Utilise `Stripe::Webhook.construct_event`
- Rejette requêtes sans signature valide

### 3.3 Protection CSRF
- `skip_before_action :verify_authenticity_token` sur webhooks uniquement
- Toutes les autres routes protégées

### 3.4 Authentification
- `before_action :authenticate_user!` sur ConnectController
- Actions admin protégées par `has_scope :by_admin`

---

## 4. COMMANDES RAKE

```bash
# Voir l'état de synchronisation
rake stripe:status

# Synchroniser tous les projets
rake stripe:sync_all_projects

# Test d'intégration complet
rake stripe:test_integration
```

---

## 5. CHECKLIST PRÉ-PRODUCTION

### Configuration Stripe Dashboard
- [ ] Compte Stripe en mode Live
- [ ] Webhook endpoint créé: `https://fiatope.com/stripe/webhooks`
- [ ] Événements sélectionnés:
  - checkout.session.completed
  - checkout.session.async_payment_succeeded
  - checkout.session.async_payment_failed
  - payment_intent.succeeded
  - payment_intent.payment_failed
  - charge.refunded
  - charge.dispute.created
  - account.updated
  - transfer.created
  - transfer.reversed
- [ ] Secret webhook copié dans STRIPE_WEBHOOK_SECRET

### Configuration Easypanel/Docker
- [ ] Variables d'environnement définies
- [ ] Migration consolidée exécutée
- [ ] Logs accessibles pour debug

### Tests manuels
- [ ] Créer un compte Stripe Connect test
- [ ] Faire une contribution test
- [ ] Vérifier la synchronisation
- [ ] Tester le transfert (montant minime)
- [ ] Vérifier le Dashboard Stripe

---

## 6. PROBLÈMES CONNUS ET SOLUTIONS

### Problème: Projets non synchronisés
**Symptôme**: Porteur a compte Stripe mais projets sans `stripe_account_id`
**Solution**: 
1. Admin clique "🔗 Synchroniser" sur le projet
2. Ou: `rake stripe:sync_all_projects`

### Problème: Onboarding incomplet
**Symptôme**: `stripe_onboarding_complete: false`
**Solution**: 
1. Générer lien onboarding depuis admin
2. Envoyer au porteur par email

### Problème: Transfert échoue
**Symptôme**: Erreur "insufficient funds"
**Solution**: 
- Vérifier que `source_transaction` est utilisé (charge_id)
- Récupérer charge_id depuis PaymentIntent si manquant

### Problème: Webhook non reçu
**Diagnostic**:
1. Vérifier logs Stripe Dashboard -> Developers -> Webhooks
2. Vérifier STRIPE_WEBHOOK_SECRET
3. Tester avec Stripe CLI en local

---

## 7. CONTACTS ET RESSOURCES

- **Documentation Stripe Connect**: https://docs.stripe.com/connect
- **Separate Charges & Transfers**: https://docs.stripe.com/connect/separate-charges-and-transfers
- **Stripe CLI**: https://stripe.com/docs/stripe-cli
- **Dashboard Stripe**: https://dashboard.stripe.com

---

*Document maintenu par l'équipe Fiatope*
