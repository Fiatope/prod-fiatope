# 🐛 DEBUG : BOUTON REWARDS NE S'AFFICHE PAS

## 🎯 PROBLÈME

Le bouton "Ajouter reward" ne s'affiche pas sur la page d'un projet, même en étant propriétaire ou admin.

---

## ✅ RÉSULTATS DU DIAGNOSTIC SERVEUR

**Script exécuté** : `quick_check_rewards_policy.rb`

```
📊 PROJET TESTÉ
  Nom          : Joro_Pay_Web
  Permalink    : joro_pay_web
  Propriétaire : djouko (djoukosocrate@gmail.com)
  last_channel : ⚠️  NIL ← PROBLÈME !

🔐 TESTS POLICY
  1. is_owned_by?(owner) : ✅ TRUE
  2. is_admin? : ❌ FALSE
  3. done_by_owner_or_admin? : ✅ TRUE
  4. policy(project).update? : ✅ TRUE

✅ LE BOUTON REWARDS DEVRAIT S'AFFICHER
```

**Conclusion** : La policy **autorise** l'affichage du bouton côté serveur.

---

## 🔍 DEBUG ÉTAPE PAR ÉTAPE DANS LE NAVIGATEUR

### ÉTAPE 1 : Vérifier la connexion

1. **Va sur** : `http://localhost:3001/projects/joro_pay_web`

2. **Ouvre la console JavaScript** : `F12` → Onglet **Console**

3. **Vérifie que tu es connecté** :
   ```javascript
   document.querySelector('meta[name="csrf-token"]')
   ```
   **Attendu** : Retourne un élément `<meta>` (si tu es connecté)
   
   **Si null** → Tu n'es PAS connecté → Connecte-toi d'abord

---

### ÉTAPE 2 : Vérifier la section rewards

Dans la **Console** :

```javascript
// 1. Vérifier que la section existe
var rewardsSection = document.querySelector('.rewards')
console.log('Section rewards:', rewardsSection)

// 2. Vérifier les data-attributes
if (rewardsSection) {
  console.log('Rewards path:', rewardsSection.dataset.rewardsPath)
  console.log('Can update:', rewardsSection.dataset.canUpdate)
} else {
  console.log('❌ Section .rewards introuvable !')
}
```

**Résultat attendu** :
```
Section rewards: <section class="rewards">...</section>
Rewards path: /projects/joro_pay_web/rewards
Can update: true
```

**Si `canUpdate: false`** → Problème de policy côté serveur (mais nos tests disent TRUE !)

---

### ÉTAPE 3 : Vérifier la requête AJAX

1. **Ouvre l'onglet** `Network` (F12)

2. **Recharge la page** : `Ctrl + Shift + R` (vidage du cache)

3. **Cherche la requête** : `/projects/joro_pay_web/rewards`

4. **Clique dessus** et regarde les onglets :

   - **Headers** → Status Code doit être `200 OK`
   - **Preview** ou **Response** → Contenu HTML retourné

**Vérifications dans la réponse** :

```javascript
// Dans la console, après le chargement de la page
fetch('/projects/joro_pay_web/rewards')
  .then(r => r.text())
  .then(html => {
    console.log('HTML retourné:', html)
    console.log('Contient .add-reward?', html.includes('add-reward'))
    console.log('Contient policy(parent).update?', html.includes('policy'))
  })
```

**Résultat attendu** :
```
Contient .add-reward? true
```

**Si false** → Le HTML ne contient PAS le bouton → Problème dans la vue `rewards/index.html.slim`

---

### ÉTAPE 4 : Vérifier si le bouton existe mais est caché

Dans la **Console** :

```javascript
// Chercher le bouton
var addRewardButton = document.querySelector('.add-reward')
console.log('Bouton add-reward:', addRewardButton)

// Si existe, vérifier s'il est visible
if (addRewardButton) {
  var styles = window.getComputedStyle(addRewardButton)
  console.log('Display:', styles.display)
  console.log('Visibility:', styles.visibility)
  console.log('Opacity:', styles.opacity)
  console.log('Height:', styles.height)
} else {
  console.log('❌ Bouton .add-reward introuvable dans le DOM !')
}
```

**Si le bouton existe mais** :
- `display: none` → Caché par CSS
- `visibility: hidden` → Caché par CSS
- `opacity: 0` → Transparent

**Solution** : Forcer l'affichage temporairement :
```javascript
if (addRewardButton) {
  addRewardButton.style.display = 'block'
  addRewardButton.style.visibility = 'visible'
  addRewardButton.style.opacity = '1'
}
```

---

### ÉTAPE 5 : Vérifier les erreurs JavaScript

Dans la **Console**, cherche des messages d'erreur en **rouge**.

Erreurs possibles :
- `Uncaught TypeError: Cannot read property 'xxx' of null`
- `Uncaught ReferenceError: xxx is not defined`
- `jQuery is not defined`
- `Backbone is not defined`

**Si erreur trouvée** → Le JavaScript crash avant d'afficher les rewards

---

### ÉTAPE 6 : Vérifier Backbone et l'initialisation

Dans la **Console** :

```javascript
// Vérifier que les dépendances sont chargées
console.log('jQuery:', typeof jQuery)          // Doit retourner "function"
console.log('Backbone:', typeof Backbone)      // Doit retourner "function"
console.log('Neighborly:', typeof Neighborly)  // Doit retourner "object"

// Vérifier que Neighborly.Rewards existe
console.log('Neighborly.Rewards:', Neighborly.Rewards)
console.log('Neighborly.Rewards.Index:', Neighborly.Rewards.Index)
```

**Résultat attendu** :
```
jQuery: "function"
Backbone: "function"
Neighborly: "object"
Neighborly.Rewards: Object {}
Neighborly.Rewards.Index: function(...)
```

**Si undefined** → Les fichiers JavaScript ne sont pas chargés

---

### ÉTAPE 7 : Forcer le chargement des rewards

Dans la **Console** :

```javascript
// Forcer la requête AJAX
var rewardsSection = document.querySelector('.rewards')
var rewardsPath = rewardsSection.dataset.rewardsPath

fetch(rewardsPath)
  .then(r => r.text())
  .then(html => {
    rewardsSection.innerHTML = html
    console.log('✅ Rewards rechargés')
  })
  .catch(err => {
    console.error('❌ Erreur:', err)
  })
```

**Si ça fonctionne** → Le problème vient de l'initialisation automatique de Backbone

---

## 🔧 SOLUTIONS SELON LE PROBLÈME

### Problème 1 : Section .rewards n'existe pas

**Cause** : La vue `projects/show.html.slim` ne contient pas la section

**Vérification** :
```bash
ruby bin/rails runner "puts File.read('app/views/projects/show.html.slim').include?('.rewards')"
```

**Solution** : Vérifier que la ligne 193 de `show.html.slim` est bien présente

---

### Problème 2 : data-can-update="false"

**Cause** : La policy retourne FALSE côté serveur (mais nos tests disent TRUE !)

**Vérification** : Connecte-toi avec le bon utilisateur (propriétaire ou admin)

**Solution** :
```bash
ruby bin/rails console
user = User.find_by_email('djoukosocrate@gmail.com')
user.update(admin: true)
```

---

### Problème 3 : Requête AJAX retourne 500 ou 404

**Cause** : Erreur dans le contrôleur `RewardsController#index`

**Vérification** : Regarde les logs du serveur Rails

**Solution** : Cherche l'erreur dans les logs et corrige-la

---

### Problème 4 : HTML retourné ne contient pas .add-reward

**Cause** : La vue `rewards/index.html.slim` ne génère pas le bouton

**Vérification** :
```bash
ruby bin/rails console
project = Project.find_by_permalink('joro_pay_web')
user = project.user
policy = ProjectPolicy.new(user, project)
puts "policy.update? = #{policy.update?}"
```

**Si FALSE** → Fix la policy (assigner un channel ou rendre admin)

**Si TRUE** → Problème dans la vue Slim

---

### Problème 5 : JavaScript ne se charge pas

**Cause** : Erreur dans `application.js` ou assets non compilés

**Solution** :
```bash
# Recompiler les assets
ruby bin/rails assets:clobber
ruby bin/rails assets:precompile

# Redémarrer le serveur
# Ctrl+C puis ruby bin/rails server -p 3001
```

---

### Problème 6 : Turbolinks interfère

**Cause** : Turbolinks ne recharge pas le JavaScript correctement

**Solution temporaire** : Désactiver Turbolinks sur cette page

Dans `app/views/projects/show.html.slim`, ajoute :
```slim
= content_for :head do
  meta name="turbolinks-visit-control" content="reload"
```

**Ou** force le rechargement :
```javascript
// Dans la console
location.reload(true)
```

---

## 🎯 CHECKLIST DE DIAGNOSTIC

Coche au fur et à mesure :

- [ ] **1. Je suis connecté** (CSRF token présent)
- [ ] **2. Je suis propriétaire ou admin** du projet
- [ ] **3. La section `.rewards` existe** dans le DOM
- [ ] **4. `data-can-update="true"`** sur la section
- [ ] **5. Requête AJAX vers `/projects/xxx/rewards`** présente dans Network
- [ ] **6. Status 200 OK** pour la requête AJAX
- [ ] **7. HTML retourné contient** `.add-reward`
- [ ] **8. Aucune erreur JavaScript** dans la console
- [ ] **9. jQuery, Backbone, Neighborly** sont chargés
- [ ] **10. Le bouton `.add-reward`** est dans le DOM

**Si toutes les cases sont cochées** → Le bouton devrait être visible !

**Si une case n'est pas cochée** → C'est là qu'est le problème

---

## 🚀 TEST FINAL RAPIDE

Copie-colle ça dans la console :

```javascript
(function() {
  console.log('='.repeat(80))
  console.log('🔍 DIAGNOSTIC REWARDS')
  console.log('='.repeat(80))
  
  // 1. Connexion
  var csrfToken = document.querySelector('meta[name="csrf-token"]')
  console.log('1. Connecté?', csrfToken ? '✅' : '❌')
  
  // 2. Section rewards
  var rewards = document.querySelector('.rewards')
  console.log('2. Section .rewards existe?', rewards ? '✅' : '❌')
  
  if (rewards) {
    console.log('   - Path:', rewards.dataset.rewardsPath)
    console.log('   - Can update:', rewards.dataset.canUpdate)
  }
  
  // 3. Bouton add-reward
  var addBtn = document.querySelector('.add-reward')
  console.log('3. Bouton .add-reward existe?', addBtn ? '✅' : '❌')
  
  if (addBtn) {
    var styles = window.getComputedStyle(addBtn)
    console.log('   - Display:', styles.display)
    console.log('   - Visibility:', styles.visibility)
  }
  
  // 4. Dépendances
  console.log('4. jQuery chargé?', typeof jQuery !== 'undefined' ? '✅' : '❌')
  console.log('5. Backbone chargé?', typeof Backbone !== 'undefined' ? '✅' : '❌')
  console.log('6. Neighborly chargé?', typeof Neighborly !== 'undefined' ? '✅' : '❌')
  
  // 5. Test requête
  if (rewards && rewards.dataset.rewardsPath) {
    console.log('\n7. Test requête AJAX...')
    fetch(rewards.dataset.rewardsPath)
      .then(r => r.text())
      .then(html => {
        console.log('   - Status: ✅ OK')
        console.log('   - Contient .add-reward?', html.includes('add-reward') ? '✅' : '❌')
        console.log('   - Longueur HTML:', html.length, 'caractères')
      })
      .catch(err => {
        console.error('   - Erreur: ❌', err.message)
      })
  }
  
  console.log('='.repeat(80))
})()
```

Ce script te donnera un diagnostic complet en une commande.

---

## 📝 RAPPORT À ENVOYER

Si le problème persiste, copie-colle le résultat du script ci-dessus et envoie-le moi.

**Format** :
```
NAVIGATEUR : Chrome/Firefox/Edge
URL : http://localhost:3001/projects/joro_pay_web
UTILISATEUR CONNECTÉ : djoukosocrate@gmail.com

RÉSULTAT DU SCRIPT :
[coller ici]

ERREURS CONSOLE :
[copier les erreurs en rouge]

SCREENSHOT NETWORK :
[capture d'écran de l'onglet Network avec la requête /rewards]
```

---

**Date** : 5 novembre 2025  
**Fichier** : 🐛_DEBUG_REWARDS_NAVIGATEUR.md
