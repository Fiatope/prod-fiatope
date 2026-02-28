# 🚀 QUICK START - PROD-FIATOPE

## ⚡ LANCEMENT RAPIDE (3 minutes)

```bash
# 1. Aller dans le dossier
cd f:\Workspace\Freelance\Fiatope\prod-fiatope

# 2. Créer la base de données
ruby bin/rails db:create

# 3. Charger le schéma
ruby bin/rails db:structure:load
# OU si pas de structure.sql
ruby bin/rails db:migrate

# 4. Charger les données initiales
ruby bin/rails db:seed

# 5. Créer le compte admin
ruby create_admin.rb

# 6. Lancer le serveur
ruby bin/rails server -p 3001
```

**Application accessible sur** : http://localhost:3001

---

## 🔑 CONNEXION ADMIN

```
Email    : admin@fiatope.com
Password : admin123
URL      : http://localhost:3001/admin
```

---

## 🆘 EN CAS DE PROBLÈME

### Bundle install n'est pas terminé ?
```bash
bundle install
```

### PostgreSQL erreur ?
```bash
# Vérifier le service
Get-Service postgresql*

# Mot de passe
Password: djouko
```

### Redis erreur ?
```bash
redis-cli ping
# Doit retourner: PONG
```

---

## 📖 DOCUMENTATION COMPLÈTE

Consulte `SETUP_COMPLETE.md` pour le guide détaillé !

---

**🎉 C'EST PARTI !**
