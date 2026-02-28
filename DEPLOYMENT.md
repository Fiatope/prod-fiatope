# 🚀 DEPLOYMENT GUIDE

## Platform: Easypanel (Heroku-like on Digital Ocean)

### Quick Deploy

```bash
./deploy_to_production.sh
```

Then click "Deploy" on Easypanel dashboard.

---

## System Dependencies

This application requires the following system packages (automatically installed via `Aptfile`):

- **build-essential** - For compiling native gems
- **git** - For Git dependencies
- **libpq-dev** - PostgreSQL client library (for `pg` gem)
- **postgresql-client** - PostgreSQL tools
- **libxml2-dev, libxslt1-dev, zlib1g-dev** - For `nokogiri` gem
- **imagemagick, libmagickwand-dev** - For `mini_magick` gem
- **xvfb, wkhtmltopdf** - For PDF generation (`wicked_pdf` gem)
- **nodejs, npm** - For asset compilation

---

## Buildpacks

Order is **critical**:

1. `heroku-buildpack-apt` - Installs system packages first
2. `heroku-buildpack-nodejs` - Installs Node.js for assets
3. `heroku-buildpack-ruby` - Installs Ruby and gems

---

## Environment Variables

### Required

```
RAILS_ENV=production
RACK_ENV=production
SECRET_KEY_BASE=<generate with: rails secret>
DATABASE_URL=postgresql://user:password@host:port/database
REDIS_URL=redis://host:port/0
```

### Optional (for features)

```
# Static files
RAILS_SERVE_STATIC_FILES=enabled
RAILS_LOG_TO_STDOUT=enabled

# AWS S3 (file uploads)
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_REGION=us-east-1
FOG_DIRECTORY=your_bucket

# Email (SMTP)
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=username
SMTP_PASSWORD=password

# MangoPay (payments)
MANGOPAY_CLIENT_ID=client_id
MANGOPAY_PASSPHRASE=passphrase
MANGOPAY_PREPRODUCTION=false
```

---

## Post-Deploy

### Run migrations

```bash
bundle exec rails db:migrate
```

### Create admin user

```ruby
bundle exec rails console

admin = User.create!(
  name: 'Admin',
  email: 'admin@fiatope.com',
  password: 'SecurePassword123!',
  password_confirmation: 'SecurePassword123!',
  admin: true
)
admin.confirm # if using Devise confirmable
```

### Create default channel

```ruby
bundle exec rails console

channel = Channel.create!(
  name: 'General',
  permalink: 'general',
  description: 'Default channel for all projects',
  user: User.find_by(admin: true)
)
```

---

## Troubleshooting

### Build fails with "Could not find X in sources"

```bash
bundle lock --add-platform x86_64-linux
git add Gemfile.lock
git commit -m "Add linux platform"
git push origin main
```

### Assets fail to compile

Ensure Node.js buildpack is configured and `.node-version` file exists.

### Native gem fails to install

Check that `Aptfile` contains the required system dependencies.

---

## Files

- `Aptfile` - System package dependencies
- `.buildpacks` - Buildpack configuration
- `.node-version` - Node.js version
- `.profile` - Environment setup at runtime
- `Procfile` - Process definitions (web, worker)
- `app.json` - Application metadata

---

## Support

For deployment issues, check:
1. Build logs in Easypanel
2. Runtime logs in Easypanel
3. Environment variables are set correctly

---

**Last updated**: November 6, 2025
