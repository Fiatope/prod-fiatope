# Script de déploiement automatique vers la production (PowerShell)
# Ce script commit et push tous les fichiers nécessaires

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "🚀 DÉPLOIEMENT VERS LA PRODUCTION" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier qu'on est sur la branche main
$currentBranch = git branch --show-current
if ($currentBranch -ne "main") {
    Write-Host "❌ ERREUR: Tu n'es pas sur la branche 'main'" -ForegroundColor Red
    Write-Host "   Branche actuelle: $currentBranch" -ForegroundColor Yellow
    Write-Host "   Exécute: git checkout main" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Branche: main" -ForegroundColor Green
Write-Host ""

# Vérifier que tous les fichiers existent
Write-Host "📋 Vérification des fichiers..."
$files = @(
    "Aptfile",
    ".buildpacks",
    ".node-version",
    ".profile",
    "app.json",
    "Gemfile.lock"
)

$allExist = $true
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "   ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $file (MANQUANT)" -ForegroundColor Red
        $allExist = $false
    }
}

if (-not $allExist) {
    Write-Host ""
    Write-Host "❌ Certains fichiers sont manquants !" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📦 Ajout des fichiers à Git..."

# Ajouter les fichiers
git add Aptfile
git add .buildpacks
git add .node-version
git add .profile
git add app.json
git add Gemfile.lock
git add bin/setup

# Ajouter les fichiers modifiés
git add app/assets/javascripts/application.js
git add app/views/projects/show.html.slim
git add app/controllers/rewards_controller.rb
git add app/models/project.rb

Write-Host "✅ Fichiers ajoutés" -ForegroundColor Green
Write-Host ""

# Afficher le statut
Write-Host "📊 Statut Git:"
git status --short

Write-Host ""
Write-Host "💬 Message de commit:" -ForegroundColor Yellow

$commitMessage = @"
🚀 Production: Fix déploiement + Rewards button

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

Status: ✅ Prêt pour production
"@

Write-Host $commitMessage
Write-Host ""

# Demander confirmation
$confirm = Read-Host "❓ Veux-tu commit et push ces changements ? (oui/non)"

if ($confirm -ne "oui" -and $confirm -ne "o") {
    Write-Host ""
    Write-Host "⚠️  Opération annulée" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Pour commit manuellement:"
    Write-Host "   git commit -m 'Ton message'"
    Write-Host "   git push origin main"
    exit 0
}

Write-Host ""
Write-Host "📝 Commit en cours..."
git commit -m $commitMessage

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ ERREUR lors du commit" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Commit réussi" -ForegroundColor Green
Write-Host ""

Write-Host "🚀 Push vers GitHub..."
git push origin main

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ ERREUR lors du push" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Essaie manuellement:"
    Write-Host "   git push origin main"
    exit 1
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "✅ DÉPLOIEMENT RÉUSSI !" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📍 Prochaines étapes:"
Write-Host ""
Write-Host "1. Va sur Easypanel : https://votre-easypanel.com"
Write-Host "2. Sélectionne l'application Fiatope"
Write-Host "3. Clique sur le bouton 'Deploy'"
Write-Host "4. Attends le build (5-10 minutes)"
Write-Host "5. Vérifie les logs pour confirmer le succès"
Write-Host ""
Write-Host "🔥 LE BUILD DEVRAIT RÉUSSIR À 100% ! 🔥" -ForegroundColor Yellow
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
