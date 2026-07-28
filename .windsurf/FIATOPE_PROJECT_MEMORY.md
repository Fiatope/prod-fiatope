# 🧠 MÉMOIRE PERMANENTE - PROJET FIATOPE

## 📌 INFORMATIONS GÉNÉRALES

**Nom du projet** : Fiatope  
**Type** : Plateforme de crowdfunding (Fork de Neighborly)  
**Framework** : Ruby on Rails  
**Base de données** : PostgreSQL 17.6  
**Localisation** : f:\Workspace\Freelance\Fiatope\prod-fiatope

---

## 🗄️ ARCHITECTURE DE LA BASE DE DONNÉES

### Tables Principales

#### 1. `contributions` (Table centrale)
```sql
- id (PK)
- project_id (FK → projects)
- user_id (FK → users)
- reward_id (FK → rewards) -- Ancienne méthode, peut être NULL
- value (montant de la contribution)
- confirmed_at (date de confirmation)
- created_at, updated_at
- state (enum: confirmed, waiting_confirmation, pending, canceled, deleted, etc.)
- payment_method (méthode de paiement)
- payment_id (ID du paiement externe)
- anonymous (boolean)
- credits (boolean)
- stripe_charge_id, stripe_transfer_id, stripe_refund_id
- cfa_value (valeur en CFA calculée)
```

**États importants** :
- `confirmed` : Contribution validée et comptabilisée
- `waiting_confirmation` : En attente de confirmation
- `pending` : En cours de traitement
- `canceled` : Annulée
- `refunded` : Remboursée
- `requested_refund` : Demande de remboursement

**Scopes Rails** :
- `available_to_count` : `['confirmed', 'requested_refund', 'refunded']`
- `available_to_display` : `['confirmed', 'requested_refund', 'refunded']`

#### 2. `contribution_rewards` (Table de liaison many-to-many)
```sql
- id (PK)
- contribution_id (FK → contributions)
- reward_id (FK → rewards)
- quantity (nombre d'unités du reward)
```

**Important** : Cette table permet à une contribution d'avoir **plusieurs rewards**.  
Format d'affichage : `"Reward Title (x2), Other Reward (x1)"`

#### 3. `rewards` (Types de contribution)
```sql
- id (PK)
- project_id (FK → projects)
- title (nom du reward, ex: "Pay +", "Premium", etc.)
- minimum_value (montant minimum)
- maximum_contributions (limite de contributeurs, nullable)
- description (texte descriptif)
- days_to_delivery
- soon (boolean)
- row_order (ordre d'affichage)
- uploaded_image
- maximum_articles
```

**Validations** :
- minimum_value >= 10.00
- maximum_contributions >= 0 (si présent)

#### 4. `projects` (Projets de crowdfunding)
```sql
- id (PK)
- name (nom du projet)
- user_id (FK → users, créateur)
- category_id (FK → categories)
- goal (objectif de financement)
- state (draft, soon, online, successful, failed, deleted, rejected)
- online_days (durée de la campagne)
- online_date (date de lancement)
- currency (EUR par défaut)
- use_stripe (boolean, true par défaut)
- stripe_account_id
- permalink (URL unique)
```

**États** :
- `draft` : Brouillon
- `soon` : À venir
- `online` : En cours
- `successful` : Réussi (objectif atteint)
- `failed` : Échoué

#### 5. `users` (Utilisateurs/Contributeurs)
```sql
- id (PK)
- name
- email
- address_city, address_state, address_number, etc.
- admin (boolean)
- created_at, updated_at
```

---

## 🔄 RELATIONS ENTRE TABLES

### Double méthode de liaison Contribution ↔ Reward

**Ancienne méthode (simple)** :
```
contributions.reward_id → rewards.id
```
Une contribution = un seul reward

**Nouvelle méthode (multiple)** :
```
contributions → contribution_rewards → rewards
```
Une contribution = plusieurs rewards possibles

### Dans le modèle Rails :
```ruby
class Contribution < ActiveRecord::Base
  belongs_to :reward                        # Relation directe (ancienne)
  has_many :contribution_rewards           # Nouvelle méthode
  has_many :rewards, through: :contribution_rewards
end
```

### Logique d'extraction des rewards :
```ruby
# Dans ContributionForProjectOwner serializer
def reward_name
  rewards_name = ""
  if contribution.rewards && contribution.rewards.present?
    contribution.contribution_rewards.each do |cr|
      rewards_name << "#{cr.reward.title}x#{cr.quantity},"
    end
  end
  rewards_name
end
```

---

## 💳 SYSTÈME DE PAIEMENT

### Providers actifs :
1. **Stripe** (principal, activé par défaut)
   - `stripe_charge_id`, `stripe_transfer_id`, `stripe_refund_id`
   - Webhook secret configuré
   
2. **Orange Money** (mobile money)
   - Table : `orange_money_transactions`
   - Multi-pays : Cameroon, Mali, Default
   
3. **Pay Plus Africa**
   - Table : `pay_plus_africa_transactions`
   
4. **MangoPay** (désactivé en production)
   - Préproduction uniquement

### Devise :
- Défaut : EUR
- Conversion CFA : Rate dans ENV['CFA_CONVERSION_RATE'] (656 par défaut)

---

## 📊 EXPORTS ET RAPPORTS

### Modèle de rapport existant :
`ContributionReportsForProjectOwner`

**Colonnes exportées** :
- project_id, project_name
- reward_name (rewards multiples agrégés)
- contribution_value
- created_at, confirmed_at
- user_email, user_name
- payer_email
- address_number
- payment_method
- city, state
- anonymous
- short_note

**Format** : CSV avec séparateur TAB (`\t`)

---

## 🔑 CONFIGURATIONS IMPORTANTES

### Environnement (.env)
```env
DATABASE_URL=postgresql://postgres:djouko@127.0.0.1:5432/prod_fiatope_development
BASE_URL=http://localhost:3001
PORT=3001
TIMEZONE=Europe/Paris
CURRENCY=EUR
PLATFORM_FEE=5.0
PLATFORM_FEE_PERCENTAGE=5.0
PLATFORM_FIX_FEE=0.5

STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

MANGOPAY_PREPRODUCTION=TRUE
```

### Extensions PostgreSQL :
- `hstore` : Stockage clé-valeur
- `pg_trgm` : Recherche par similarité trigram
- `unaccent` : Recherche sans accents

---

## 🎯 RÈGLES MÉTIER CRITIQUES

### Contributions confirmées :
Une contribution est considérée comme **confirmée** si :
- `state = 'confirmed'`
- `confirmed_at IS NOT NULL`

### Contributions comptabilisées :
Les contributions comptées dans les totaux ont les états :
- `confirmed`
- `requested_refund`
- `refunded`

### Anonymat :
Si `contributions.anonymous = true` :
- Masquer le nom → "Anonyme"
- Masquer l'email → "***@***.***"

### Rewards :
- Une contribution peut avoir 0, 1 ou plusieurs rewards
- Vérifier d'abord `contribution_rewards`, puis `reward_id` direct
- Format : "Reward Title (xQuantity), Other Reward (xQuantity)"

---

## 📁 STRUCTURE DES FICHIERS

### Modèles principaux :
- `app/models/contribution.rb`
- `app/models/reward.rb`
- `app/models/project.rb`
- `app/models/user.rb`
- `app/models/contribution_reports_for_project_owner.rb`

### Serializers :
- `app/serializers/contribution_for_project_owner.rb`

### Controllers de rapports :
- `app/controllers/reports/contribution_reports_for_project_owners_controller.rb`

### Migrations :
- `db/migrate/` (nombreuses migrations)
- `db/structure.sql` : Structure complète de la base

---

## 🚨 POINTS D'ATTENTION

### 1. Double système de rewards
Toujours vérifier les deux sources :
```sql
-- Rewards multiples (priorité)
LEFT JOIN contribution_rewards cr ON c.id = cr.contribution_id
LEFT JOIN rewards r ON cr.reward_id = r.id

-- Reward direct (fallback)
LEFT JOIN rewards r_direct ON c.reward_id = r_direct.id
```

### 2. États des contributions
Ne jamais compter les états :
- `waiting_confirmation`
- `pending`
- `canceled`
- `deleted`

### 3. Frais de plateforme
- Fee percentage : 5%
- Fee fixe : 0.5
- Peut être payé par l'utilisateur ou déduit

### 4. Stripe
- Système principal de paiement
- Transferts automatiques aux porteurs de projets
- Gestion des refunds

---

## 📝 SCRIPTS SQL CRÉÉS

### 1. `SCRIPT_EXTRACTION_URGENT.sql`
Script simplifié pour extraction rapide des contributions confirmées d'un projet.

### 2. `extract_contributions_project_3049.sql`
Script complet avec statistiques détaillées (3 requêtes).

### Utilisation type :
```sql
SELECT ... FROM contributions c
INNER JOIN projects p ON c.project_id = p.id
INNER JOIN users u ON c.user_id = u.id
LEFT JOIN (
  SELECT cr.contribution_id,
    STRING_AGG(CONCAT(r.title, ' (x', cr.quantity, ')'), ', ') AS reward_titles
  FROM contribution_rewards cr
  INNER JOIN rewards r ON cr.reward_id = r.id
  GROUP BY cr.contribution_id
) cr ON c.id = cr.contribution_id
LEFT JOIN rewards r_direct ON c.reward_id = r_direct.id
WHERE c.project_id = ? AND c.state = 'confirmed'
```

---

## 🔧 COMMANDES UTILES

### Rails Console :
```bash
cd f:/Workspace/Freelance/Fiatope/prod-fiatope
rails console

# Trouver un projet
Project.find(3049)

# Contributions confirmées d'un projet
Contribution.where(project_id: 3049, state: 'confirmed')

# Export CSV
ContributionReportsForProjectOwner.new(Project.find(3049)).to_csv
```

### PostgreSQL :
```bash
psql postgresql://postgres:djouko@127.0.0.1:5432/prod_fiatope_development

# Lister les projets
SELECT id, name, state FROM projects ORDER BY id DESC LIMIT 10;

# Contributions d'un projet
SELECT COUNT(*), SUM(value) FROM contributions 
WHERE project_id = 3049 AND state = 'confirmed';
```

---

## 📅 HISTORIQUE

**2026-07-25** : Analyse complète de la structure et création des scripts d'extraction pour projet 3049

---

## 🎯 PROCHAINES ÉTAPES POSSIBLES

- Automatiser les rapports de contributions
- Dashboard de suivi en temps réel
- Webhooks Stripe pour notifications
- Export automatique vers Google Sheets
- API REST pour accès externe aux stats

---

**Dernière mise à jour** : 25 juillet 2026  
**Version de la base** : PostgreSQL 17.6  
**Framework** : Ruby on Rails (version Neighborly fork)
