# Dockerfile optimisé pour Fiatope - Rails 6.1 + Ruby 3.1
FROM ruby:3.1.4-slim

# Variables d'environnement
ENV RAILS_ENV=production \
    RACK_ENV=production \
    NODE_VERSION=20.x \
    BUNDLER_VERSION=2.4.22 \
    RAILS_SERVE_STATIC_FILES=enabled \
    RAILS_LOG_TO_STDOUT=enabled \
    BUNDLE_WITHOUT=development:test

# Installation des dépendances système
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    libpq-dev \
    postgresql-client \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    imagemagick \
    libmagickwand-dev \
    xvfb \
    wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

# Installation de Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest && \
    rm -rf /var/lib/apt/lists/*

# Création du répertoire de travail
WORKDIR /app

# Installation de bundler
RUN gem install bundler -v $BUNDLER_VERSION

# Copie des fichiers de dépendances ET des gems locales (lib/)
COPY Gemfile Gemfile.lock ./
COPY lib/ ./lib/

# Installation des gems (--jobs 1 pour limiter usage espace disque temporaire)
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 1 --retry 3 && \
    bundle clean --force && \
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -name "*.c" -delete && \
    find /usr/local/bundle/gems/ -name "*.o" -delete

# Copie du reste de l'application
COPY . .

# Copie du fichier database.yml pour Docker
RUN cp config/database.yml.docker config/database.yml

# Précompiler les assets PENDANT le build (pas au runtime)
# Utiliser bin/rails directement pour éviter problèmes de résolution bundler
ENV SECRET_KEY_BASE=dummy_secret_for_assets_precompile_only
RUN bin/rails assets:precompile

# Créer le script d'entrée simplifié (migrations seulement)
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Démarrer Xvfb pour wkhtmltopdf\n\
Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &\n\
export DISPLAY=:99\n\
\n\
# Exécuter les migrations au démarrage\n\
echo "==> Exécution des migrations..."\n\
bin/rails db:migrate 2>/dev/null || echo "Migrations déjà appliquées ou échouées"\n\
\n\
# Exécuter la commande passée en argument\n\
exec "$@"\n\
' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# Exposition du port
EXPOSE 3000

# Point d'entrée
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Commande par défaut
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
