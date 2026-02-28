# .profile - Script exécuté au démarrage de chaque conteneur

# Set display for wkhtmltopdf (nécessaire pour la génération de PDF)
export DISPLAY=:99

# Start Xvfb in background for headless rendering
Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &

# Ensure all assets are accessible
export RAILS_SERVE_STATIC_FILES=enabled
export RAILS_LOG_TO_STDOUT=enabled

echo "✅ Environment configured"
