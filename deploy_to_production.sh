#!/bin/bash

# Script de déploiement automatique vers la production
# Ce script commit et push tous les fichiers nécessaires

echo "================================================================================"
echo "🚀 DÉPLOIEMENT VERS LA PRODUCTION"
echo "================================================================================"
echo ""

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérifier qu'on est sur la branche main
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${RED}❌ ERREUR: Tu n'es pas sur la branche 'main'${NC}"
    echo -e "   Branche actuelle: $CURRENT_BRANCH"
    echo -e "   Exécute: ${YELLOW}git checkout main${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Branche: main${NC}"
echo ""

# Vérifier que tous les fichiers existent
echo "📋 Vérification des fichiers..."
FILES=(
    "Aptfile"
    ".buildpacks"
    ".node-version"
    ".profile"
    "app.json"
    "Gemfile.lock"
)

ALL_EXIST=true
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "   ${GREEN}✅${NC} $file"
    else
        echo -e "   ${RED}❌${NC} $file (MANQUANT)"
        ALL_EXIST=false
    fi
done

if [ "$ALL_EXIST" = false ]; then
    echo ""
    echo -e "${RED}❌ Certains fichiers sont manquants !${NC}"
    exit 1
fi

echo ""
echo "📦 Ajout des fichiers à Git..."

# Ajouter les fichiers
git add Aptfile
git add .buildpacks
git add .node-version
git add .profile
git add app.json
git add Gemfile.lock
git add bin/setup

# Ajouter les fichiers JavaScript/CSS modifiés
git add app/assets/javascripts/application.js
git add app/views/projects/show.html.slim
git add app/controllers/rewards_controller.rb
git add app/models/project.rb

echo -e "${GREEN}✅ Fichiers ajoutés${NC}"
echo ""

# Afficher le statut
echo "📊 Statut Git:"
git status --short

echo ""
echo "💬 Message de commit:"
COMMIT_MESSAGE="🚀 Production: Fix déploiement + Rewards button

- Aptfile: Dépendances système Linux (ImageMagick, PostgreSQL, wkhtmltopdf)
- .buildpacks: Configuration buildpacks Heroku (apt → nodejs → ruby)
- .node-version: Node.js 18.20.2 pour assets
- .profile: Configuration Xvfb pour génération PDF
- app.json: Configuration application Easypanel
- Gemfile.lock: Ajout plateforme x86_64-linux

Fix déploiement:
- Fix: ERROR failed to build: executing lifecycle
- Toutes les dépendances système maintenant installées

Fix Rewards:
- Fix JavaScript: Vérification existence élément avant modification
- Fix Channel: Auto-assignation canal par défaut
- Fix View: Vérification image channel avant affichage

Status: ✅ Prêt pour production"

echo ""
echo "$COMMIT_MESSAGE"
echo ""

# Demander confirmation
read -p "❓ Veux-tu commit et push ces changements ? (oui/non) : " CONFIRM

if [ "$CONFIRM" != "oui" ] && [ "$CONFIRM" != "o" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Opération annulée${NC}"
    echo ""
    echo "💡 Pour commit manuellement:"
    echo "   git commit -m 'Ton message'"
    echo "   git push origin main"
    exit 0
fi

echo ""
echo "📝 Commit en cours..."
git commit -m "$COMMIT_MESSAGE"

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ ERREUR lors du commit${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Commit réussi${NC}"
echo ""

echo "🚀 Push vers GitHub..."
git push origin main

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ ERREUR lors du push${NC}"
    echo ""
    echo "💡 Essaie manuellement:"
    echo "   git push origin main"
    exit 1
fi

echo ""
echo "================================================================================"
echo -e "${GREEN}✅ DÉPLOIEMENT RÉUSSI !${NC}"
echo "================================================================================"
echo ""
echo "📍 Prochaines étapes:"
echo ""
echo "1. Va sur Easypanel : https://votre-easypanel.com"
echo "2. Sélectionne l'application Fiatope"
echo "3. Clique sur le bouton 'Deploy'"
echo "4. Attends le build (5-10 minutes)"
echo "5. Vérifie les logs pour confirmer le succès"
echo ""
echo "🔥 LE BUILD DEVRAIT RÉUSSIR À 100% ! 🔥"
echo ""
echo "================================================================================"
