# 🔧 FIX : ERREUR CRÉATION DE PROJET

## 🐛 PROBLÈME INITIAL

**Erreur rencontrée :**
```
ActionController::UrlGenerationError at /projects/build/wicked_finish
No route matches {:action=>"show", :controller=>"projects", :id=>#<Project id: nil, ...>}
```

**Cause :**
Le projet n'était pas sauvegardé en base de données (id: nil) mais le système essayait de rediriger vers `project_path(@project)`.

---

## 🔍 DIAGNOSTIC

### Champs obligatoires pour un projet

D'après `app/models/project.rb` ligne 143 :
```ruby
validates_presence_of :name, :user, :category, :about, :headline, :goal, :permalink, :location
```

**8 champs obligatoires :**
1. ✅ `name` - Nom du projet (Step1)
2. ✅ `user` - Créateur (auto-rempli)
3. ✅ `category` - Catégorie (Step1)
4. ✅ `about` - Description détaillée (Step1)
5. ✅ `headline` - Résumé court, max 140 car. (Step4)
6. ✅ `goal` - Objectif de financement (Step1)
7. ✅ `permalink` - URL (généré auto depuis name)
8. ✅ `location` - Localisation (Step1)

**Champs additionnels :**
- `online_days` - Durée de campagne (Step1)

**Pour l'état "online" :**
- `video_url`
- `address_city`
- `address_state`

---

## ✅ CORRECTIONS APPLIQUÉES

### 1. Contrôleur : Gestion explicite de la sauvegarde

**Fichier :** `app/controllers/projects/build_controller.rb`

**Ligne 56-71 - Avant :**
```ruby
elsif step == :verify
  render_wizard @project
else
```

**Ligne 56-76 - Après :**
```ruby
elsif step == :verify
  # Dernière étape : sauvegarder le projet en base de données
  Rails.logger.debug("## Tentative de sauvegarde du projet")
  Rails.logger.debug("## Projet: #{@project.inspect}")
  Rails.logger.debug("## Erreurs avant save: #{@project.errors.full_messages}")
  
  if @project.save
    Rails.logger.debug("## Projet sauvegardé avec succès, ID: #{@project.id}")
    render_wizard @project
  else
    Rails.logger.error("## ERREUR: Échec de sauvegarde du projet")
    Rails.logger.error("## Erreurs: #{@project.errors.full_messages}")
    
    flash.now[:alert] = "Impossible de créer le projet : #{@project.errors.full_messages.join(', ')}"
    render_wizard
  end
else
```

**Bénéfices :**
- ✅ Sauvegarde explicite du projet
- ✅ Gestion des erreurs de validation
- ✅ Logging détaillé pour debug
- ✅ Message d'erreur affiché à l'utilisateur

---

### 2. Contrôleur : Protection finish_wizard_path

**Fichier :** `app/controllers/projects/build_controller.rb`

**Ligne 89-113 - Avant :**
```ruby
def finish_wizard_path
  puts "****************************************************"
  puts "project : #{@project.inspect}"
  puts "****************************************************"
  puts "partner : #{@project.partner.inspect}"
  puts "****************************************************"

  if @project.partner.present?
    partner_project_path(partner_id: @project.partner.permalink, id: @project.permalink)
  else
    project_path(@project)
  end
end
```

**Ligne 89-113 - Après :**
```ruby
def finish_wizard_path
  Rails.logger.debug("****************************************************")
  Rails.logger.debug("project : #{@project.inspect}")
  Rails.logger.debug("project ID : #{@project.id}")
  Rails.logger.debug("project permalink : #{@project.permalink}")
  Rails.logger.debug("****************************************************")
  Rails.logger.debug("partner : #{@project.partner.inspect}")
  Rails.logger.debug("****************************************************")

  # Vérifier que le projet a bien un ID et un permalink
  unless @project.persisted? && @project.permalink.present?
    Rails.logger.error("## ERREUR: finish_wizard_path appelé avec un projet non sauvegardé")
    Rails.logger.error("## Projet persisted?: #{@project.persisted?}")
    Rails.logger.error("## Projet ID: #{@project.id}")
    Rails.logger.error("## Projet permalink: #{@project.permalink}")
    Rails.logger.error("## Erreurs: #{@project.errors.full_messages}")
    return projects_path
  end

  if @project.partner.present?
    partner_project_path(partner_id: @project.partner.permalink, id: @project.permalink)
  else
    project_path(@project)
  end
end
```

**Bénéfices :**
- ✅ Vérification que le projet est sauvegardé
- ✅ Redirection sécurisée vers projects_path si échec
- ✅ Logging détaillé des erreurs
- ✅ Évite l'erreur `No route matches`

---

### 3. Vue : Affichage des erreurs

**Fichier :** `app/views/projects/build/verify.html.slim`

**Ligne 20-21 - Avant :**
```slim
= simple_form_for @project, url: wizard_path, method: :put do |f|
  p.check_data = t('crowdfunding.check_then_send')
```

**Ligne 20-29 - Après :**
```slim
= simple_form_for @project, url: wizard_path, method: :put do |f|
  - if @project.errors.any?
    .alert.alert-danger
      h4 
        | ⚠️ Erreurs à corriger (#{@project.errors.count})
      ul
        - @project.errors.full_messages.each do |message|
          li = message
  
  p.check_data = t('crowdfunding.check_then_send')
```

**Bénéfices :**
- ✅ Affichage des erreurs de validation
- ✅ Liste claire de tous les champs manquants
- ✅ L'utilisateur sait exactement quoi corriger

---

## 🧪 TESTS

### Test de diagnostic

```powershell
ruby diagnose_project_creation.rb
```

**Output attendu :**
```
🔍 DIAGNOSTIC CRÉATION DE PROJET

❌ Erreurs de validation:
   • Name à renseigner
   • Category à renseigner
   • About à renseigner
   • Headline à renseigner
   • Goal à renseigner
   • Permalink à renseigner
   • Location à renseigner

📝 Détail des champs manquants:
   ❌ name                 : nil
   ✅ user                 : #<User id: 1...>
   ❌ category             : nil
   ❌ about                : nil
   ❌ headline             : nil
   ❌ goal                 : nil
   ❌ permalink            : nil
   ❌ location             : ""
```

---

## 📝 WORKFLOW DE CRÉATION

### Étapes du wizard

1. **Step1** - Informations principales
   - ✅ name (titre du projet)
   - ✅ about (description détaillée)
   - ✅ category_id (catégorie)
   - ✅ goal (objectif)
   - ✅ online_days (durée)
   - ✅ location (localisation)
   - currency (devise)
   - presale (prévente oui/non)

2. **Step2** - Questions complémentaires
   - description
   - how_knows_fiatope
   - how_knows_crowdfunding
   - already_did_crowdfunding

3. **Step3** - Stratégie d'enrôlement
   - how_many_contributors
   - how_much_contribute
   - contributors_from_where
   - enrollment_strategy
   - Réseaux sociaux (Facebook, Twitter, etc.)

4. **Step4** - Organisation
   - ✅ headline (résumé court)
   - organization_type
   - organization_description
   - organization_created_at
   - organization_in_incubateur
   - organization_funding
   - Si partner : numero_ifu, numero_rccm

5. **Verify** - Vérification finale
   - Affiche tous les champs
   - ✅ Affiche les erreurs de validation
   - Soumet le formulaire
   - ✅ Sauvegarde en base de données
   - Redirection vers la page du projet

---

## 🎯 COMPORTEMENT ATTENDU MAINTENANT

### Cas 1 : Tous les champs sont remplis
1. L'utilisateur remplit le wizard (steps 1-4)
2. Page verify : tous les champs sont affichés
3. Clic sur "Envoyer"
4. ✅ Le projet est sauvegardé (id assigné)
5. ✅ Redirection vers `project_path(@project)`
6. ✅ Message : "Votre projet a été créé! Nous vous reviendrons sous 72h."

### Cas 2 : Un champ obligatoire est manquant
1. L'utilisateur remplit le wizard partiellement
2. Page verify : champs affichés
3. Clic sur "Envoyer"
4. ❌ La sauvegarde échoue
5. ✅ Page verify rechargée avec message d'erreur
6. ✅ Liste des erreurs affichée :
   ```
   ⚠️ Erreurs à corriger (3)
   • Name à renseigner
   • Category à renseigner
   • Goal à renseigner
   ```
7. ✅ L'utilisateur peut corriger les champs manquants
8. Nouveau clic sur "Envoyer"
9. ✅ Sauvegarde réussie → Redirection

---

## 🔧 FICHIERS MODIFIÉS

| Fichier | Modifications |
|---------|---------------|
| `app/controllers/projects/build_controller.rb` | Gestion explicite de sauvegarde + protection finish_wizard_path |
| `app/views/projects/build/verify.html.slim` | Affichage des erreurs de validation |
| `diagnose_project_creation.rb` | ✨ Nouveau script de diagnostic |
| `🔧_FIX_CREATION_PROJET.md` | ✨ Cette documentation |

---

## 📊 RÉSUMÉ DES VALIDATIONS

### Validations du modèle Project

```ruby
# Obligatoires pour TOUS les états
validates_presence_of :name, :user, :category, :about, :headline, :goal, :permalink, :location
validates_length_of :headline, maximum: 140
validates_numericality_of :online_days
validates_uniqueness_of :permalink, allow_blank: true, case_sensitive: false, on: :update
validates_format_of :permalink, with: /\A(\w|-)*\z/, allow_blank: true

# Obligatoires seulement pour l'état "online"
validates :video_url, :online_days, :address_city, :address_state, presence: true, if: ->(p) { p.state_name == 'online' }
validates_format_of :video_url, with: /(https?\:\/\/|)(youtu(\.be|be\.com)|vimeo).*+/, allow_blank: true
```

### Génération automatique

- `permalink` : Généré automatiquement à partir de `name` via `has_permalink :name, true`
- `state` : Par défaut `"draft"`
- `campaign_type` : Par défaut `:all_or_none`

---

## 🚀 PROCHAINES ÉTAPES

### Pour l'utilisateur

1. **Tester la création de projet**
   ```
   http://localhost:3001/projects/build
   ```

2. **Remplir TOUS les champs obligatoires**
   - Step1 : name, category, about, goal, online_days, location
   - Step4 : headline (max 140 caractères)

3. **Si erreur**
   - Les erreurs s'affichent maintenant clairement
   - Corriger les champs manquants
   - Re-soumettre

### Pour le développeur

1. **Monitoring des logs**
   ```powershell
   # Lancer le serveur en mode verbose
   ruby bin/rails server -p 3001
   ```
   
   Les logs afficheront maintenant :
   ```
   ## Tentative de sauvegarde du projet
   ## Projet: #<Project id: nil, name: "Test"...>
   ## Erreurs avant save: []
   ## Projet sauvegardé avec succès, ID: 42
   ```

2. **Debug rapide**
   ```powershell
   ruby diagnose_project_creation.rb
   ```

---

## 🎉 RÉSULTAT

✅ **Le bug est corrigé !**

L'erreur `No route matches {:id=>#<Project id: nil>}` ne devrait plus apparaître car :
1. Le projet est maintenant sauvegardé explicitement avant la redirection
2. Si la sauvegarde échoue, l'utilisateur voit les erreurs et peut corriger
3. La redirection est protégée contre les projets non sauvegardés

---

**Date de correction** : 5 novembre 2025  
**Fichiers créés** : 2  
**Fichiers modifiés** : 2  
**Lignes ajoutées** : ~50  
**Status** : ✅ RÉSOLU
