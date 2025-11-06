# Dockerfile optimisé pour Fiatope - Rails 6.1 + Ruby 3.1
FROM ruby:3.1.4-slim

# Variables d'environnement
ENV RAILS_ENV=production \
    RACK_ENV=production \
    NODE_VERSION=18.20.2 \
    BUNDLER_VERSION=2.4.22 \
    RAILS_SERVE_STATIC_FILES=enabled \
    RAILS_LOG_TO_STDOUT=enabled

# Installation des dépendances système (optimisé)
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

# Installation de Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest && \
    rm -rf /var/lib/apt/lists/*

# Création du répertoire de travail
WORKDIR /app

# Installation de bundler
RUN gem install bundler -v $BUNDLER_VERSION

# Copie des fichiers de dépendances
COPY Gemfile Gemfile.lock ./

# Installation des gems (avec cache)
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3 && \
    bundle clean --force

# Copie du reste de l'application
COPY . .

# Précompilation des assets (avec cache)
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile && \
    rm -rf tmp/cache

# Nettoyage pour réduire la taille de l'image
RUN apt-get purge -y --auto-remove build-essential git && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -rf ~/.bundle ~/.gem

# Configuration Xvfb pour wkhtmltopdf
RUN echo '#!/bin/bash\nXvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &\nexec "$@"' > /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Exposition du port
EXPOSE 3000

# Point d'entrée
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Commande par défaut
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
