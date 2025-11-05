# 🔍 DIAGNOSTIC : BOUTON "AJOUTER REWARD" NON VISIBLE

## 🎯 PROBLÈME

Le bouton pour ajouter un reward ne s'affiche pas sur la page d'un projet (ex: `localhost:3001/projects/joro_pay_web`).

---

## 📋 ARCHITECTURE DU SYSTÈME

### 1. Affichage des Rewards

**Fichier** : `app/views/projects/show.html.slim` (ligne 193)
```slim
section.rewards[data-rewards-path=project_rewards_path(@project) data-can-update="#{policy(@project).update?}"]
```

Cette section est **chargée dynamiquement par JavaScript**.

### 2. Chargement JavaScript

**Fichier** : `app/assets/javascripts/neighborly/rewards/index.js.coffee` (lignes 18-24)
```coffeescript
load: ->
  that = this
  $.ajax(
    url: that.$rewards.data("rewards-path")  # Appelle /projects/:id/rewards
    success: (data) ->
      $(that.el).html data
  )
```

### 3. Contrôleur

**Fichier** : `app/controllers/rewards_controller.rb` (lignes 6-9)
```ruby
def index
  @rewards = parent.rewards.rank(:row_order)
  respond_with @rewards, layout: !request.xhr?
end
```

### 4. Vue des Rewards

**Fichier** : `app/views/rewards/index.html.slim` (lignes 857-872)
```slim
- if policy(parent).update?    # ← CONDITION CRITIQUE
  .reward.new-reward-form
    .loading.hide
      = image_tag 'loading.gif'
    .form-content

  .reward.add-reward
    = link_to new_project_reward_path(parent), ... do
      i.icon-et-plus
      br/
      = t('.add')
```

**🔥 LE BOUTON NE S'AFFICHE QUE SI `policy(parent).update?` EST `TRUE` !**

---

## 🔐 VÉRIFICATION DES PERMISSIONS

### Policy utilisée : `RewardPolicy` → hérite de `ProjectInheritedPolicyHelpers`

**Fichier** : `app/policies/project_inherited_policy_helpers.rb`

```ruby
def create?
  done_by_owner_or_admin? || is_channel_admin?
end
```

**Fichier** : `app/policies/application_policy.rb`

```ruby
def done_by_owner_or_admin?
  is_owned_by?(user) || is_admin?
end
```

**Fichier** : `app/policies/project_inherited_policy_helpers.rb`

```ruby
def is_owned_by?(user)
  user.present? && record.project.user == user
end

def is_channel_admin?
  user.present? && ( record.project.last_channel.try(:user) == user ||
                      user.channels.include?(record.project.last_channel) )
end
```

### ✅ LE BOUTON S'AFFICHE SI :

1. **L'utilisateur est propriétaire du projet**
   - `project.user == current_user`

2. **OU l'utilisateur est admin de la plateforme**
   - `current_user.admin? == true`

3. **OU l'utilisateur est admin du channel**
   - `project.last_channel.user == current_user`
   - OU `current_user.channels.include?(project.last_channel)`

---

## 🧪 DIAGNOSTIC ÉTAPE PAR ÉTAPE

### ÉTAPE 1 : Lance le script de diagnostic

```powershell
ruby diagnose_reward_button.rb
```

Le script va te demander :
1. Le **permalink du projet** (ex: `joro_pay_web`)
2. L'**ID de l'utilisateur** connecté

Il affichera :
- ✅ Les informations du projet
- ✅ Les informations de l'utilisateur
- ✅ Les 3 vérifications de permissions
- ✅ Le résultat final avec explications

### ÉTAPE 2 : Teste dans le navigateur

1. **Lance le serveur**
   ```powershell
   ruby bin/rails server -p 3001
   ```

2. **Ouvre la console JavaScript** (F12)

3. **Va sur la page du projet**
   ```
   http://localhost:3001/projects/joro_pay_web
   ```

4. **Vérifie dans la console**
   ```javascript
   // Vérifie que la section rewards existe
   document.querySelector('.rewards')
   
   // Vérifie l'attribut data-can-update
   document.querySelector('.rewards').dataset.canUpdate
   // Doit retourner "true" pour que le bouton s'affiche
   
   // Vérifie si le bouton est présent
   document.querySelector('.add-reward')
   ```

5. **Vérifie la requête AJAX**
   - Ouvre l'onglet **Network** (F12)
   - Rafraîchis la page
   - Cherche une requête vers `/projects/joro_pay_web/rewards`
   - Clique dessus et vérifie la **réponse HTML**
   - La réponse doit contenir `.add-reward` si tu as les permissions

---

## 🐛 CAUSES POSSIBLES DU PROBLÈME

### 1. ❌ L'utilisateur n'a pas les permissions

**Symptômes** :
- Le HTML de la réponse AJAX ne contient PAS `.add-reward`
- `data-can-update="false"` dans le HTML

**Diagnostic** :
```powershell
ruby diagnose_reward_button.rb
```

**Solutions** :
- Connecte-toi avec le **propriétaire du projet**
- Connecte-toi avec un **compte admin**
- Donne les droits admin à ton utilisateur :
  ```ruby
  rails console
  user = User.find_by(email: 'ton@email.com')
  user.update(admin: true)
  ```

### 2. ❌ JavaScript ne charge pas les rewards

**Symptômes** :
- Aucune requête AJAX vers `/projects/:id/rewards` dans Network
- La section `.rewards` est vide

**Diagnostic** :
```javascript
// Dans la console
Neighborly.Rewards.Index
// Doit retourner un objet Backbone
```

**Solutions** :
- Vérifie que les fichiers JS sont chargés :
  ```javascript
  typeof Backbone  // Doit retourner "function"
  typeof Neighborly  // Doit retourner "object"
  ```

- Vérifie la console pour des erreurs JavaScript

- Recompile les assets :
  ```powershell
  ruby bin/rails assets:precompile
  ```

### 3. ❌ Erreur dans le contrôleur

**Symptômes** :
- Requête AJAX vers `/projects/:id/rewards` retourne une erreur 500

**Diagnostic** :
- Vérifie les logs du serveur Rails
- Cherche une erreur Ruby dans les logs

**Solutions** :
- Vérifie que le projet existe :
  ```ruby
  rails console
  Project.find_by_permalink!('joro_pay_web')
  ```

### 4. ❌ Problème de session/authentification

**Symptômes** :
- Tu es déconnecté
- `current_user` est `nil`

**Diagnostic** :
```javascript
// Dans la console, vérifie si tu es connecté
document.querySelector('meta[name="csrf-token"]')
// Doit exister
```

**Solutions** :
- Connecte-toi : `http://localhost:3001/users/sign_in`
- Vérifie les cookies de session

---

## ✅ SOLUTIONS RAPIDES

### Solution 1 : Donner les droits admin à ton utilisateur

```powershell
ruby bin/rails console
```

```ruby
# Trouve ton utilisateur
user = User.find_by(email: 'ton@email.com')

# Donne-lui les droits admin
user.update(admin: true)

# Vérifie
user.admin?  # Doit retourner true
```

### Solution 2 : Se connecter avec le propriétaire du projet

```powershell
ruby bin/rails console
```

```ruby
# Trouve le projet
project = Project.find_by_permalink('joro_pay_web')

# Trouve le propriétaire
owner = project.user

puts "Email du propriétaire : #{owner.email}"
# Connecte-toi avec cet email
```

### Solution 3 : Créer un compte admin de test

```powershell
ruby bin/rails console
```

```ruby
admin = User.create!(
  email: 'admin-test@fiatope.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Admin Test',
  admin: true,
  birthday: Date.new(1990, 1, 1),
  nationality: 'FR',
  residence_country: 'FR'
)

admin.skip_confirmation!
admin.save

puts "Admin créé ! Email: admin-test@fiatope.com / Password: password123"
```

---

## 🔧 SCRIPT DE VÉRIFICATION AUTOMATIQUE

Un script Ruby complet a été créé : `diagnose_reward_button.rb`

### Utilisation :

```powershell
ruby diagnose_reward_button.rb
```

**Le script va :**
1. ✅ Lister tous les projets
2. ✅ Te demander quel projet tester
3. ✅ Lister tous les utilisateurs
4. ✅ Te demander quel utilisateur tester
5. ✅ Vérifier les 3 conditions de permissions
6. ✅ Tester la policy réelle
7. ✅ Afficher le diagnostic complet avec solutions

---

## 📊 TABLEAU DE DÉCISION

| Condition | Utilisateur | Résultat |
|-----------|-------------|----------|
| Propriétaire du projet | `project.user == current_user` | ✅ Bouton visible |
| Admin plateforme | `current_user.admin? == true` | ✅ Bouton visible |
| Admin du channel | `current_user == channel.user` | ✅ Bouton visible |
| Aucune des 3 | - | ❌ Bouton caché |

---

## 🎯 MÉTHODE DE TEST GARANTIE

### 1. Test avec l'admin existant

```powershell
# Lance le serveur
ruby bin/rails server -p 3001
```

```
# Connecte-toi
Email: admin@fiatope.com
Password: admin123
```

```
# Va sur le projet
http://localhost:3001/projects/joro_pay_web
```

**Résultat attendu** : ✅ Le bouton "Ajouter reward" DOIT s'afficher (car admin)

### 2. Test avec le propriétaire du projet

```powershell
ruby diagnose_reward_button.rb
```

Le script t'affichera l'email du propriétaire. Connecte-toi avec cet email.

**Résultat attendu** : ✅ Le bouton "Ajouter reward" DOIT s'afficher (car propriétaire)

### 3. Test avec un utilisateur lambda

Crée un utilisateur de test NON-admin :

```ruby
rails console
user = User.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  name: 'Test User',
  admin: false,  # ← PAS ADMIN
  birthday: Date.new(1990, 1, 1),
  nationality: 'FR',
  residence_country: 'FR'
)
user.skip_confirmation!
user.save
```

Connecte-toi avec cet utilisateur.

**Résultat attendu** : ❌ Le bouton "Ajouter reward" NE DOIT PAS s'afficher (car pas de permissions)

---

## 🚨 ATTENTION - NE PAS MODIFIER

**⚠️ IMPORTANT** : Le système fonctionne correctement comme il est. Le bouton est caché **volontairement** pour les utilisateurs sans permissions.

**NE PAS** :
- ❌ Retirer la condition `if policy(parent).update?`
- ❌ Modifier les policies sans analyse
- ❌ Donner les droits admin à tous les utilisateurs

**À FAIRE** :
- ✅ Se connecter avec le bon utilisateur (propriétaire ou admin)
- ✅ Vérifier les permissions de l'utilisateur actuel
- ✅ Utiliser le script de diagnostic pour identifier le problème

---

## 📝 LOGS UTILES

### Vérifier les logs Rails

```powershell
# Dans le terminal du serveur Rails
# Cherche les lignes comme :
Started GET "/projects/joro_pay_web/rewards" for 127.0.0.1
Processing by RewardsController#index as */*
Parameters: {"project_id"=>"joro_pay_web"}
Completed 200 OK
```

### Vérifier dans Rails console

```ruby
rails console

# Trouve le projet
project = Project.find_by_permalink('joro_pay_web')

# Trouve ton utilisateur
user = User.find_by(email: 'ton@email.com')

# Teste la policy
reward = Reward.new(project: project)
policy = RewardPolicy.new(user, reward)
policy.update?  # Doit retourner true ou false
```

---

## ✅ CHECKLIST DE VÉRIFICATION

Avant de signaler un bug, vérifie :

- [ ] Je suis **connecté** à l'application
- [ ] Je suis sur la bonne page du projet (`/projects/:permalink`)
- [ ] J'ai vérifié mes permissions avec `diagnose_reward_button.rb`
- [ ] J'ai vérifié la console JavaScript (F12)
- [ ] J'ai vérifié l'onglet Network pour la requête AJAX
- [ ] J'ai vérifié que je suis bien :
  - [ ] Propriétaire du projet OU
  - [ ] Admin de la plateforme OU
  - [ ] Admin du channel
- [ ] J'ai testé avec le compte `admin@fiatope.com`

---

**Date de création** : 5 novembre 2025  
**Fichiers créés** : 2  
**Status** : ✅ SYSTÈME FONCTIONNEL - Diagnostic disponible
