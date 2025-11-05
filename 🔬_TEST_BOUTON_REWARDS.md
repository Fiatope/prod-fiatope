# 🔬 TEST : POURQUOI LE BOUTON REWARDS NE S'AFFICHE PAS

## ✅ CE QUI EST CONFIRMÉ

- ✅ Le projet a un canal (Général)
- ✅ La policy `project.update?` retourne **TRUE** pour le propriétaire
- ✅ La policy `project.update?` retourne **TRUE** pour l'admin
- ✅ Le code est correct dans `rewards/index.html.slim` ligne 857

**Donc le problème est ailleurs !**

---

## 🎯 HYPOTHÈSES

### Hypothèse 1 : current_user est NIL dans la requête AJAX
La session n'est pas transmise dans la requête AJAX.

### Hypothèse 2 : Le JavaScript ne charge pas la section rewards
Erreur JavaScript qui empêche le chargement.

### Hypothèse 3 : La réponse du serveur est vide
Le serveur ne renvoie pas le HTML complet.

---

## 🧪 TEST ÉTAPE PAR ÉTAPE

### ÉTAPE 1 : Redémarrer le serveur

**Important** : Le code a été modifié, il faut redémarrer !

```powershell
# Arrête le serveur (Ctrl+C)
# Relance :
ruby bin/rails server -p 3001
```

---

### ÉTAPE 2 : Se connecter

1. **Va sur** : `http://localhost:3001`
2. **Connecte-toi avec** : `djoukosocrate@gmail.com` (propriétaire du projet)

---

### ÉTAPE 3 : Accéder à la page du projet

**Va sur** : `http://localhost:3001/projects/joro_pay_web`

**Attendu** : La page se charge sans erreur

---

### ÉTAPE 4 : Vérifier les logs du serveur

Dans le terminal où Rails tourne, cherche ces lignes :

```
================================================================================
REWARDS#INDEX DEBUG
  Project: Joro_Pay_Web (joro_pay_web)
  Current user: djouko (djoukosocrate@gmail.com)    ← DOIT PAS ÊTRE NIL !
  Rewards count: X
  XHR request?: true
  policy(parent).update?: true                      ← DOIT ÊTRE TRUE !
================================================================================
```

**Si `Current user: NIL`** → Problème d'authentification AJAX

**Si `policy(parent).update?: false`** → Problème de permissions

---

### ÉTAPE 5 : Tester via la console JavaScript

1. **Appuie sur** : `F12` (ouvre la console)
2. **Va dans l'onglet** : `Console`
3. **Copie-colle ce code** :

```javascript
fetch('/projects/joro_pay_web/rewards')
  .then(r => r.text())
  .then(html => {
    console.log('='.repeat(80))
    console.log('TEST REWARDS AJAX')
    console.log('='.repeat(80))
    console.log('Longueur HTML:', html.length)
    console.log('Contient "add-reward"?', html.includes('add-reward'))
    console.log('Contient "policy"?', html.includes('policy'))
    console.log('')
    
    if (!html.includes('add-reward')) {
      console.log('❌ LE BOUTON N\'EST PAS DANS LA RÉPONSE')
      console.log('')
      console.log('Extrait de la réponse:')
      console.log(html.substring(0, 1000))
    } else {
      console.log('✅ Le bouton EST dans la réponse HTML')
      console.log('→ Le problème vient du JavaScript qui ne l\'affiche pas')
    }
    
    console.log('='.repeat(80))
  })
  .catch(err => {
    console.error('❌ ERREUR AJAX:', err)
  })
```

---

### ÉTAPE 6 : Interpréter les résultats

#### CAS 1 : `Current user: NIL` dans les logs

**Problème** : La session n'est pas transmise dans les requêtes AJAX

**Solution** :
```ruby
# config/initializers/session_store.rb
# Vérifier que les cookies de session sont correctement configurés
```

---

#### CAS 2 : `policy(parent).update?: false` dans les logs

**Problème** : Les permissions ne fonctionnent pas

**Solution** : Vérifier les roles et le channel

---

#### CAS 3 : Le HTML ne contient PAS "add-reward"

**Problème** : La vue ne rend pas le bouton

**Causes possibles** :
- `current_user` est nil dans la vue
- La condition `if policy(parent).update?` retourne false
- Erreur silencieuse dans la vue

**Solution** : Regarder les logs du serveur

---

#### CAS 4 : Le HTML CONTIENT "add-reward" mais le bouton ne s'affiche pas

**Problème** : Le JavaScript ne remplace pas le contenu

**Solution** : Vérifier le JavaScript qui charge les rewards

---

## 🔍 VÉRIFICATION SUPPLÉMENTAIRE

Si le problème persiste, vérifie que le JavaScript charge bien la section rewards :

```javascript
// Dans la console
var rewardsSection = document.querySelector('.rewards')
console.log('Section rewards:', rewardsSection)
console.log('Data path:', rewardsSection ? rewardsSection.dataset.rewardsPath : 'N/A')
console.log('Can update:', rewardsSection ? rewardsSection.dataset.canUpdate : 'N/A')
```

**Attendu** :
```
Section rewards: <section class="rewards">
Data path: /projects/joro_pay_web/rewards
Can update: true
```

**Si `Can update: false`** → Le problème vient de `policy(@project).update?` dans `projects/show.html.slim`

---

## 📋 CHECKLIST

Coche au fur et à mesure :

- [ ] Serveur redémarré
- [ ] Connecté avec le bon utilisateur (propriétaire)
- [ ] Page projet chargée sans erreur
- [ ] Logs du serveur affichent `Current user: djouko` (pas NIL)
- [ ] Logs du serveur affichent `policy(parent).update?: true`
- [ ] Test JavaScript effectué
- [ ] Résultat du test analysé

---

## 🚨 SI RIEN NE FONCTIONNE

Envoie-moi :

1. **Les logs du serveur** (partie REWARDS#INDEX DEBUG)
2. **Le résultat du test JavaScript** (copie-colle de la console)
3. **Capture d'écran** de la page du projet
4. **Avec quel utilisateur** tu es connecté

---

**Date** : 5 novembre 2025  
**Statut** : 🔬 DIAGNOSTIC EN COURS
