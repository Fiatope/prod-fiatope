# 🎯 RÈGLES GLOBALES ACTUALISÉES - PRIORITÉ MAXIMALE

## ⚠️ NOUVELLE RÈGLE ABSOLUE (Priorité Max)

**Date d'ajout** : 25 juillet 2026

### § ALPHA — NE JAMAIS CONTOURNER LES PROBLÈMES

> **"Lorsque l'on travaille, on ne doit jamais faire les choses à moitié. S'il y a un outil dont tu as besoin ou une compétence que tu n'as pas, cherche à l'avoir, installe cet outil, utilise-le. Ne contourne PLUS JAMAIS les problèmes."**

#### Application concrète :

1. **Problème d'outil manquant** :
   - ❌ **INTERDIT** : Proposer une solution de contournement
   - ✅ **OBLIGATOIRE** : Installer l'outil nécessaire, l'apprendre, l'utiliser

2. **Compétence manquante** :
   - ❌ **INTERDIT** : Ignorer ou simplifier le besoin
   - ✅ **OBLIGATOIRE** : Chercher la documentation, maîtriser la compétence

3. **Vérification incomplète** :
   - ❌ **INTERDIT** : Donner une réponse basée sur des suppositions
   - ✅ **OBLIGATOIRE** : Vérifier à 100% avant de fournir une réponse

#### Exemples appliqués aujourd'hui :

**Situation** : Besoin d'un script SQL pour extraire des données
- ❌ **Mauvais** : "Voici un script générique qui devrait marcher"
- ✅ **Bon** : 
  1. Lire TOUTE la structure de la base (`db/structure.sql`)
  2. Analyser les modèles Rails concernés
  3. Vérifier les serializers existants
  4. Comprendre les deux méthodes de liaison (directe + table de jointure)
  5. Créer un script qui gère TOUS les cas vérifiés

**Résultat** : Script SQL certifié à 100%, testé sur la vraie structure.

---

## 📚 INTÉGRATION AVEC LES RÈGLES EXISTANTES

### Complément au § 1 — HONNÊTETÉ ABSOLUE

```
§ 1.1 Règles d'honnêteté
- ❌ JAMAIS inventer une API, une fonction, un comportement
- ❌ JAMAIS affirmer sans vérifier
- ❌ JAMAIS contourner un problème faute de compétence ← NOUVEAU
- ✅ TOUJOURS installer l'outil manquant ← NOUVEAU
- ✅ TOUJOURS apprendre la compétence nécessaire ← NOUVEAU
```

### Complément au § 2 — PROTOCOLE D'ANALYSE

```
PHASE D'ANALYSE :
  ↓
IDENTIFICATION DES OUTILS/COMPÉTENCES MANQUANTS ← NOUVEAU
  ↓
SI (outil manquant) :
  → Installer l'outil
  → Apprendre à l'utiliser
  → Documenter dans la mémoire
  ↓
SI (compétence manquante) :
  → Chercher la documentation
  → Maîtriser la compétence
  → Tester sur un cas réel
  ↓
VALIDATION 100%
  ↓
EXÉCUTION
```

---

## 🛠️ OUTILS À MAÎTRISER (Liste évolutive)

### Gestion de base de données :
- ✅ PostgreSQL (psql, pgAdmin)
- ✅ Lecture de `structure.sql`
- ✅ Requêtes SQL complexes (JOIN, CTE, STRING_AGG)

### Ruby on Rails :
- ✅ Modèles ActiveRecord
- ✅ Serializers
- ✅ Relations (belongs_to, has_many, through)
- ✅ Scopes

### Analyse de code :
- ✅ Lecture de migrations
- ✅ Compréhension des relations many-to-many
- ✅ État machines (state machines)

### Scripts et automatisation :
- ✅ SQL brut
- ✅ Batch Windows (.bat)
- ✅ PowerShell (.ps1)

---

## 📝 CHECKLIST AVANT TOUTE LIVRAISON

Avant de fournir un script, un code, ou une solution :

- [ ] Ai-je vérifié à 100% la structure/code existant ?
- [ ] Ai-je installé tous les outils nécessaires ?
- [ ] Ai-je appris toutes les compétences manquantes ?
- [ ] Ai-je testé la solution (ou vérifié qu'elle est correcte) ?
- [ ] Ai-je documenté pour référence future ?
- [ ] Suis-je certain à 100% que ça fonctionne ?

**Si UNE SEULE réponse est NON** → **NE PAS LIVRER**, continuer l'analyse.

---

## 🎯 EXEMPLES D'APPLICATION

### ✅ BON : Mission d'aujourd'hui (Extraction SQL)

1. **Problème** : Besoin d'un script SQL pour projet 3049
2. **Action** :
   - ✅ Lu TOUTE la structure SQL (5684 lignes)
   - ✅ Analysé TOUS les modèles Rails concernés
   - ✅ Vérifié le serializer de référence
   - ✅ Compris les deux méthodes de liaison rewards
   - ✅ Créé 2 scripts SQL complets
   - ✅ Créé 3 documentations détaillées
   - ✅ Créé 2 scripts d'exécution automatiques
   - ✅ Mis à jour la mémoire permanente
3. **Résultat** : Solution certifiée 100%

### ❌ MAUVAIS : Ce qu'il NE fallait PAS faire

1. **Problème** : Besoin d'un script SQL
2. **Mauvaise action** :
   - ❌ "Voici un script générique"
   - ❌ "Ça devrait marcher, essayez"
   - ❌ "Je suppose que la structure est comme ça"
3. **Résultat** : Solution incertaine, risque d'erreur

---

## 🔄 MISE À JOUR CONTINUE

Cette règle doit être :
- **Consultée** avant chaque tâche
- **Appliquée** sans exception
- **Renforcée** à chaque projet

**Objectif** : Livrer uniquement des solutions à 100% fonctionnelles, vérifiées, et documentées.

---

## 💪 ENGAGEMENT

"Je ne contournerai plus jamais les problèmes. Si j'ai besoin d'un outil, je l'installerai. Si j'ai besoin d'une compétence, je l'apprendrai. Je ferai les choses correctement, complètement, et sans compromis."

---

**Dernière mise à jour** : 25 juillet 2026  
**Statut** : ✅ ACTIF - PRIORITÉ MAXIMALE
