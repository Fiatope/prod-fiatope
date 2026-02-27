# Guide de Test — Crowdfunding Fiatope (Stripe Connect)

> **Pour qui ?** Développeurs, testeurs et équipe Fiatope  
> **Branche :** `socrate`  
> **Mise à jour :** 2026-02-21  

---

## Architecture du système de financement participatif

```
[Contributeur] ──paiement carte──▶ [Stripe Checkout]
                                         │ transfer_group: "project_N"
                                         ▼
                           [Compte PLATEFORME Fiatope]
                            Fonds retenus jusqu'à décision
                                         │
              ┌──────────────────────────┴──────────────────────┐
              │ Campagne réussie                                  │ Campagne échouée
              ▼                                                   ▼
  [Porteur demande retrait]                         [Admin rembourse contributeurs]
  → état: request_funds                              → CampaignSettlement#process_refunds!
              │
              ▼
  [Admin approuve → Transfert Stripe]
  → CampaignSettlement#process!
  → Déduction commission 5%
  → état: paid
              │
              ▼
  [Espace de virement Express → IBAN porteur]
  Délai: 2–7 jours ouvrés
              │
              ▼
  [Webhook payout.paid → Email confirmation porteur]
```

---

## Variables d'environnement (`.env`)

| Variable | Valeur | Rôle |
|---|---|---|
| `PLATFORM_FEE` | `5.0` | Commission totale (%) annoncée au porteur |
| `STRIPE_SECRET_KEY` | `sk_test_...` | Clé API Stripe (mode test) |
| `STRIPE_PUBLISHABLE_KEY` | `pk_test_...` | Clé publique Stripe |
| `STRIPE_WEBHOOK_SECRET` | `whsec_...` | Signature des webhooks |

> **Calcul :** Porteur reçoit = Brut × (1 − 5%) = 95% du total collecté  
> La commission 5% couvre les frais bancaires + frais de service Fiatope.

---

## Scénario 1 — Nouveau porteur de projet (sans compte de virement)

### Objectif
Vérifier que le porteur est guidé pour configurer son espace de virement AVANT de pouvoir demander son argent.

### Étapes
1. **Créer un compte** et un projet sur l'application
2. **Lancer le projet** (via l'admin si nécessaire)
3. Sur la **page du projet** (sidebar) → bouton "⚙ Configurer mon espace de virement" doit apparaître
4. Cliquer → redirige vers **`/projects/:slug/pay`**
5. Sur la page pay → section "Configuration requise" avec bouton "Configurer mon espace de virement"
6. Cliquer → formulaire d'onboarding (informations personnelles + IBAN)
7. Compléter l'onboarding jusqu'à la fin
8. **Retour automatique** vers `/projects/:slug/pay`

### Résultat attendu
- ✅ Bouton "Configurer mon espace de virement" visible dans la sidebar du projet
- ✅ Page pay affiche "Configuration requise" si non configuré
- ✅ Après configuration → affiche "Espace de virement configuré ✓"
- ✅ **Le porteur ne voit plus le bouton de configuration** après complétion

### Script de vérification
```bash
rails runner tmp/test_audit_final.rb
```

---

## Scénario 2 — Porteur configuré demande son virement

### Objectif
Vérifier le flux complet : porteur demande → admin traite → fonds virés.

### Prérequis
- Porteur avec espace de virement configuré (`stripe_onboarding_complete = true`)
- Au moins une contribution Stripe confirmée sur le projet
- Projet en état `online`, `successful`, `waiting_funds` ou `failed`

### Étapes côté porteur
1. Aller sur la **page du projet** → sidebar → bouton "💰 Demander le retrait de mes fonds"
2. OU aller sur **`/projects/:slug/pay`** → bouton "Demander mon virement de X€"
3. Confirmer dans la boîte de dialogue
4. **Flash ✅** : "Demande de virement envoyée ! Notre équipe va vérifier..."
5. La page affiche maintenant : "Demande de virement en cours de traitement" (orange)

### Résultat attendu côté porteur
- ✅ État du projet passe à `request_funds`
- ✅ Bouton de demande remplacé par le badge "Demande en cours"
- ✅ Page pay affiche le bloc orange de confirmation
- ✅ **Aucun transfert Stripe immédiat** — seulement changement d'état

### Étapes côté admin (interface admin)
1. Aller sur **`/admin/projects`**
2. Trouver le projet → badge "💸 Retrait demandé" (orange) dans la colonne État
3. Menu déroulant → "Transférer" → modal de confirmation
4. Vérifier les montants (brut, commission 5%, net porteur)
5. Cocher "Je confirme vouloir transférer les fonds"
6. Cliquer "Confirmer"

### Résultat attendu côté admin
- ✅ Flash ✅ : "Transfert de X€ effectué ! Les fonds arrivent sur le compte bancaire..."
- ✅ État du projet passe à `paid` (badge vert "✅ Payé")
- ✅ Contribution marquée `stripe_transferred = true`
- ✅ `project.stripe_settled_at` renseigné
- ✅ `project.stripe_transfer_id` renseigné

### Résultat côté porteur (après admin)
- ✅ Page pay affiche "Fonds virés avec succès !"
- ✅ Date du virement affichée
- ✅ Porteur reçoit email de confirmation

---

## Scénario 3 — Campagne all-or-none échouée → remboursement

### Objectif
Vérifier que les contributeurs sont remboursés si le projet all-or-none n'atteint pas son objectif.

### Prérequis
- Projet `campaign_type = 'all_or_none'` expiré sans atteindre l'objectif
- Projet en état `failed` ou `waiting_funds`

### Étapes côté admin
1. Aller sur **`/admin/projects`**
2. Trouver le projet expiré
3. Menu déroulant → "Rembourser" → modal de remboursement
4. **Sélectionner les contributions** à rembourser (checkboxes individuelles)
5. Ou "Tout sélectionner" pour rembourser tous
6. Vérifier les montants retenus (frais Stripe ~1.4% + 0.25€ + commission 5%)
7. Cocher "Je confirme vouloir rembourser les contributeurs"
8. Cliquer "Confirmer"

### Résultat attendu
- ✅ Flash ✅ : "Remboursement effectué pour X contributions"
- ✅ Contributions marquées `stripe_refunded = true`
- ✅ `stripe_refund_id` renseigné pour chaque contribution
- ✅ Contributeurs remboursés sur leur carte bancaire (2-7j)

---

## Scénario 4 — Campagne flexible (porteur reçoit toujours les fonds)

### Objectif
Vérifier que le porteur reçoit ses fonds même si l'objectif n'est pas atteint (campagne flexible).

### Prérequis
- Projet `campaign_type != 'all_or_none'` (flexible par défaut)
- Au moins une contribution confirmée

### Vérification
- La méthode `project.flexible?` retourne `true`
- Le porteur peut demander son virement quel que soit l'état du projet (online, failed, successful)
- L'admin peut transférer même si `progress < 100%`

### Script de test
```bash
rails runner -e development -r ./config/environment.rb -e "puts Project.first.flexible?"
```

---

## Scénario 5 — Protection anti-double transfert

### Objectif
Vérifier qu'un projet ne peut pas être transféré deux fois.

### Test manuel
1. Effectuer un premier transfert (Scénario 2)
2. Retourner sur l'admin → le bouton "Transférer" ne doit plus apparaître
3. Si le porteur retourne sur `/pay`, affichage : "Fonds virés avec succès !"

### Vérifications techniques
- `project.stripe_settlement_type == 'transferred'` bloque le re-transfert
- `project.state == 'paid'` bloque la demande porteur
- La page pay affiche l'état final (plus de bouton de demande)

---

## Scénario 6 — Onboarding incomplet (porteur n'a pas terminé la configuration)

### Objectif
Vérifier que le porteur ne peut pas demander son virement sans avoir configuré son espace de virement.

### Test manuel
1. Porteur sans `stripe_onboarding_complete = true` en base
2. Accéder à `/projects/:slug/pay`
3. → Affichage de la section "Configuration requise"
4. Accéder à `/projects/:slug/request_payout` (POST)
5. → Flash alert : "Vous devez d'abord configurer votre espace de virement"
6. → Redirection vers `/pay`

### Résultat attendu
- ✅ Impossible de demander un virement sans onboarding complété
- ✅ Message clair guidant vers la configuration

---

## Scénario 7 — Test des webhooks

### Objectif
Vérifier que les événements Stripe sont correctement traités.

### Webhooks configurés
| Événement | Handler | Action |
|---|---|---|
| `checkout.session.completed` | `handle_checkout_completed` | Confirme la contribution |
| `payment_intent.succeeded` | `handle_payment_intent_succeeded` | Log + backup |
| `charge.refunded` | `handle_charge_refunded` | Marque contribution remboursée |
| `account.updated` | `handle_account_updated` | Met à jour `stripe_onboarding_complete` |
| `transfer.created` | `handle_transfer_created` | Log du transfert |
| `payout.paid` | `handle_payout_paid` | Notifie porteur (fonds arrivés) |
| `payout.failed` | `handle_payout_failed` | Alerte admin |
| `charge.dispute.created` | `handle_dispute_created` | Log du litige |

### Test avec Stripe CLI (mode test)
```bash
# Installer Stripe CLI et s'authentifier
stripe login

# Écouter les webhooks en local
stripe listen --forward-to localhost:3001/neighborly/stripe/webhooks

# Simuler un paiement réussi
stripe trigger checkout.session.completed

# Simuler un payout réussi
stripe trigger payout.paid

# Simuler un payout échoué
stripe trigger payout.failed
```

### Vérification
```bash
# Vérifier les logs Rails
tail -f log/development.log | grep "PAYOUT\|WEBHOOK\|Transfer"
```

---

## Scénario 8 — Calcul des frais (vérification arithmétique)

### Formule
```
Commission = Brut × PLATFORM_FEE% (défaut 5%)
Net porteur = Brut × (1 - PLATFORM_FEE%)
```

### Exemples chiffrés
| Brut collecté | Commission (5%) | Porteur reçoit |
|---|---|---|
| 100 € | 5,00 € | 95,00 € |
| 500 € | 25,00 € | 475,00 € |
| 1 000 € | 50,00 € | 950,00 € |
| 2 500 € | 125,00 € | 2 375,00 € |

> **Note :** La commission 5% est le montant TOTAL annoncé au porteur.  
> Elle couvre à la fois les frais bancaires Stripe (~1.4% + 0.25€/txn) et  
> les frais de service Fiatope. Le porteur sait qu'il recevra 95% de ce qui a été collecté.

### Script de vérification des calculs
```bash
rails runner tmp/test_audit_final.rb
```

---

## Scénario 9 — Auto-finish des campagnes (tâche cron)

### Objectif
Vérifier que les campagnes expirées changent d'état automatiquement.

### Fonctionnement
Le cron `rake cron` s'exécute régulièrement (Heroku Scheduler) :
1. Trouve tous les projets `online` ou `waiting_funds` expirés (`Project.to_finish`)
2. Lance `CampaignFinisherWorker` pour chaque projet via Sidekiq
3. Le worker appelle `project.finish` qui déclenche la machine à états :
   - **Flexible** : `online` → `waiting_funds` → `successful` (fonds disponibles pour virement)
   - **All-or-none atteint** : `online` → `waiting_funds` → `successful`
   - **All-or-none non atteint** : `online` → `waiting_funds` → `failed` (remboursement admin)

### Test manuel
```bash
# Voir les projets à financer
rails runner "puts Project.to_finish.count"

# Lancer le cron manuellement
rails cron

# Vérifier Sidekiq
rails runner "puts Sidekiq::Queue.new.size"
```

---

## Scénario 10 — Interface admin complète

### Colonnes de la table projets
| Colonne | Information |
|---|---|
| État | Badge coloré avec l'état actuel (online, request_funds, paid, etc.) |
| Stripe | ✅ Prêt / ⏳ Onboarding / ❌ Non activé |
| Actions | Menu déroulant avec toutes les actions disponibles |

### Badges d'état côté admin
| Badge | Couleur | Signification |
|---|---|---|
| online | bleu | Campagne en cours |
| waiting_funds | jaune | En attente de fin |
| successful | vert | Objectif atteint |
| failed | rouge | Campagne échouée |
| 💸 Retrait demandé | orange | Porteur a demandé son virement |
| ✅ Payé | vert foncé | Fonds virés au porteur |

### Actions disponibles par état
| Action | Disponible quand |
|---|---|
| Activer Stripe | Toujours si pas encore activé |
| Générer lien onboarding | Compte Stripe non complet |
| Transférer | Contributions en attente + compte prêt |
| Rembourser | Contributions non remboursées |
| 💸 Marquer "Retrait demandé" | Admin peut forcer l'état |
| ✅ Marquer comme Payé | Après transfert manuel |

---

## Commandes de test rapide

```bash
# Audit complet (21 vérifications)
rails runner tmp/test_audit_final.rb

# Test tous les scénarios crowdfunding (10 scénarios)
rails runner tmp/test_crowdfunding_complet_v2.rb

# Vérifier l'état de la DB
rails runner "puts Project.group(:state).count"
rails runner "puts Contribution.group(:payment_method, :state).count"

# Vérifier les contributions Stripe
rails runner "puts Contribution.where(payment_method: 'Stripe').group(:state).count"

# Vérifier les transferts
rails runner "puts Contribution.where(stripe_transferred: true).count"
```

---

## Points de contrôle avant déploiement

- [ ] `PLATFORM_FEE=5.0` dans `.env` de production
- [ ] `STRIPE_WEBHOOK_SECRET` configuré avec le bon secret Stripe production
- [ ] Webhook URL configurée dans le dashboard Stripe : `https://votre-domaine/neighborly/stripe/webhooks`
- [ ] Événements Stripe à activer dans le dashboard :
  - `checkout.session.completed`
  - `payment_intent.succeeded`
  - `charge.refunded`
  - `account.updated`
  - `transfer.created`
  - `payout.paid`
  - `payout.failed`
  - `charge.dispute.created`
- [ ] Sidekiq opérationnel (pour `CampaignFinisherWorker`)
- [ ] Tâche cron configurée : `rake cron` toutes les heures

---

## Lexique (termes internes vs Stripe)

| Terme affiché au client | Terme technique (Stripe) |
|---|---|
| Espace de virement | Stripe Connect Express Account |
| Compte de virement | Stripe Connect Account ID |
| Configuration requise | Onboarding incomplet |
| Virement bancaire | Stripe Transfer |
| Fonds en route | Stripe Payout |
| Paiement sécurisé | Stripe Checkout |

> **Règle :** Les clients (porteurs et contributeurs) ne voient jamais le nom "Stripe" dans les pages de gestion.  
> Seuls les admins voient les références Stripe (ID de compte, transfert, etc.) dans l'interface admin.

---

*Guide généré automatiquement — branche `socrate`*
