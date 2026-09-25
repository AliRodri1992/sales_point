# Configuración

Guía de configuración de NEXO POS.

---

## ⚙️ Archivos de Configuración

### ApplicationController

```ruby
# config/application.rb
class Application < Rails::Application
  config.load_defaults 8.1
  config.i18n.default_locale = :es
  config.i18n.available_locales = %i[en es ko]
  config.active_job.queue_adapter = :sidekiq
end
```

---

## 🔑 Credential Configuration

### Database Configuration

**Archivo:** `config/database.yml`

```yaml
default: &default
  adapter: postgresql
  encoding: utf8
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 10 } %>
  username: <%= ENV['POSTGRES_USER'] %>
  password: <%= ENV['POSTGRES_PASSWORD'] %>
  host: <%= ENV['POSTGRES_HOST'] || 'db' %>
  port: <%= ENV['POSTGRES_PORT'] || 5432 %>

development:
  <<: *default
  database: sale_point_development

test:
  <<: *default
  database: sale_point_test

production:
  primary: &primary_production
    <<: *default
    database: <%= ENV['POSTGRES_DB'] %>
  # ... caches, queues, cable
```

---

## 🔐 Rails Master Key

```bash
# Ver master key
cat config/master.key

# Guardar en variable de entorno
export RAILS_MASTER_KEY=$(cat config/master.key)

# Para producción, usar secrets
kamal env set RAILS_MASTER_KEY -s -e sale_point
```

---

## 🔧 Environment Configuration

### Development

```bash
# .env.development
POSTGRES_USER=sale_point
POSTGRES_PASSWORD=password
POSTGRES_HOST=localhost
RAILS_ENV=development
```

### Production

```bash
# Variables requeridas
POSTGRES_HOST=prod-db.example.com
POSTGRES_USER=production_user
POSTGRES_PASSWORD=very_secure_password
RAILS_MASTER_KEY=32_char_key_from_master.key
RAILS_ENV=production
```

---

## 🌍 Internationalization (i18n)

### Configuración

```ruby
# config/application.rb
config.i18n.default_locale = :es
config.i18n.available_locales = %i[en es ko]
```

### Idiomas disponibles

```text
config/locales/
├── en.yml    # English
├── es.yml    # Español (default)
└── ko.yml    # Korean
```

### Database Backend

Para traducciones dinámicas desde la base de datos:

```ruby
# config/initializers/i18n_database_backend.rb
I18n.backend = I18n::Backend::DatabaseBackend.new
```

---

## 🎨 Assets Configuration

### PostCSS/Tailwind

```javascript
// package.json
{
  "scripts": {
    "build:css": "npx @tailwindcss/cli -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify",
    "build:css:watch": "npx @tailwindcss/cli -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --watch"
  }
}
```

### Configure JavaScript

```javascript
// app/javascript/application.js
import "@hotwired/turbo-rails"
import Swal from "sweetalert2"
import "./controllers"
import "./admin/dashboard"

window.Swal = Swal
```

---

## 📊 Active Job Configuration

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

### Sidekiq Configuration

```yaml
# config/sidekiq.yml
:concurrency: 5
:queues:
  - default
  - mailers
  - critical
```

---

## 💬 ActionCable Configuration

```yaml
# config/cable.yml
development:
  adapter: async

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
```

---

## 📦 Active Storage Configuration

```yaml
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

---

## 🔐 Devise Configuration

**Archivo:** `config/initializers/devise.rb`

```ruby
Devise.setup do |config|
  config.secret_key = Rails.application.credentials.devise_secret_key
  config.path = '/'
  config.navigational_formats = ['*/*', :html, :turbo_stream]
  config.sign_out_via = :delete
end
```

---

## 🔒 Security Configuration

### Rack::Attack

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  throttle("requests by IP", limit: 300, period: 5.minutes) { |req| req.ip }
  throttle("login attempts", limit: 5, period: 60.seconds) { |req| req.ip if req.path == "/users/sign_in" && req.post? }
end
```

### Secure Headers

```ruby
# config/initializers/secure_headers.rb
SecureHeaders::Configuration.default do |config|
  config.default_src :none
  config.script_src :self
  config.style_src :self, :unsafe_inline
end
```

---

## 📊 Rails Configuration by Environment

### Development

```ruby
# config/environments/development.rb
config.cache_classes = false
config.eager_load = false
config.consider_all_requests_local = true
config.debug_exception_response_format = :default
config.hosts = nil
config.active_storage.service = :local
```

### Production

```ruby
# config/environments/production.rb
config.cache_classes = true
config.eager_load = true
config.consider_all_requests_local = false
config.force_ssl = true
config.public_file_server.enabled = true
config.lograge.enabled = true
```

---

## 📋 Environment Variables Reference

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `RAILS_ENV` | Entorno Rails | development, production |
| `RACK_ENV` | Entorno Rack | development, production |
| `RAILS_MASTER_KEY` | Key de credentials | 32 caracteres |
| `POSTGRES_HOST` | Host de DB | localhost, db |
| `POSTGRES_PORT` | Puerto de DB | 5432 |
| `POSTGRES_USER` | Usuario de DB | sale_point |
| `POSTGRES_PASSWORD` | Password de DB | - |
| `POSTGRES_DB` | Nombre de DB | sale_point_development |

---

## 🧪 Logging Configuration

```ruby
# config/environments/development.rb
config.log_level = :debug
config.log_tags = [:request_id]

# config/environments/production.rb
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
```

---

## 📈 Frame Rate Configuration

```ruby
# config/initializers/rack_attack.rb
# Ajustar según necesidades
throttle("requests by IP", limit: 300, period: 5.minutes)
throttle("login attempts", limit: 5, period: 60.seconds)
throttle("admin abuse", limit: 10, period: 1.minute)
```