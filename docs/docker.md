# Docker y Despliegue

Documentación de Docker y despliegue de NEXO POS.

---

## 🐳 Docker Configuration

### Archivos Principales

```text
sale_point/
├── Dockerfile                  # Imagen Docker principal
├── docker-compose.dev.yml      # Compose para desarrollo
├── docker-compose.prod.yml     # Compose para producción
└── config/deploy.yml           # Configuración Kamal
```

### Dockerfile

```dockerfile
# Dockerfile (ejemplo básico)
FROM ruby:3.3.6

RUN apt-get update -qq && \
    apt-get install -y libpq-dev nodejs build-essential

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
```

### Docker Compose (Desarrollo)

La configuración real es `docker-compose.dev.yml`. En desarrollo separa los procesos:

- `web`: ejecuta `db:prepare` y Puma en el puerto 3000, sin Foreman ni observadores de recursos.
- `assets`: ejecuta Foreman únicamente para observar cambios de JavaScript y CSS; comparte los archivos del proyecto con `web`.
- `sidekiq`: procesa trabajos en segundo plano.
- `db` y `redis`: almacenan datos en volúmenes persistentes.

Todos estos servicios usan `restart: unless-stopped`. Si un observador de assets falla, Compose reinicia `assets` **sin detener Rails**. Si Rails falla, Compose intenta reiniciar `web`, pero **eso no corrige la causa raíz**; hay que consultar su error.

Después de actualizar esta configuración:

```bash
docker compose -f docker-compose.dev.yml up -d --build
docker compose -f docker-compose.dev.yml ps -a
docker compose -f docker-compose.dev.yml logs --tail=150 web assets sidekiq
```

Se puede detener el servicio `assets` mientras se investiga sin interrumpir el servidor: `docker compose -f docker-compose.dev.yml stop assets`. Los cambios en JS/CSS no se recompilarán hasta volver a iniciarlo.

**Si `web` vuelve a detenerse**, tomar el diagnóstico antes de limpiar/recrear recursos:

```bash
docker inspect rails_sale_point --format='OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}}'
docker compose -f docker-compose.dev.yml logs --timestamps --tail=250 web assets
docker stats --no-stream rails_sale_point sidekiq_sale_point
```

Un `OOMKilled=true` indica que Docker terminó el proceso por memoria; `OOMKilled=false` requiere examinar los logs, incluso cuando el código de salida no es cero. En Docker Desktop, confirma el límite de memoria asignado, especialmente al ejecutar RSpec, Chromium y Sidekiq a la vez. El hook pre-push local **no ejecuta Docker ni RSpec**, para evitar esperas y bloqueos al publicar cambios. GitHub Actions ejecuta la suite completa. Cuando se ejecuta **manualmente** `bash bin/overcommit-rspec`, las pruebas corren en un contenedor `web` temporal y aislado, sin detener el servidor principal.

**Importante:** no ejecutar `docker compose down -v` ni `docker volume prune` para solucionar este problema; eso podría borrar la base de datos de desarrollo.

---

## 🚀 Kamal - Despliegue

**Archivo:** `config/deploy.yml`

### Configuración Base

```yaml
# config/deploy.yml
service: sale_point

servers:
  web:
    - 192.168.0.1

# Docker registry configuration
registry:
  server: localhost:5555

# Environment variables
env:
  secret:
    - RAILS_MASTER_KEY
  clear:
    SOLID_QUEUE_IN_PUMA: true
    WEB_CONCURRENCY: 2

# Volumes
volumes:
  - "sale_point_storage:/rails/storage"

# Asset path for zero-downtime deploy
asset_path: /rails/public/assets
```

---

## 📦 Proceso de Despliegue

### 1. Preparar el Ambiente

```bash
# Configurar variables de entorno
kamal env set RAILS_MASTER_KEY -s -e sale_point
kamal env set POSTGRES_PASSWORD -s -e sale_point_db

# Configurar secrets en servidor remoto
kamal secrets init
```

### 2. Build de Imagen

```bash
# Construir imagen local
kamal build

# Construir con remote builder (más rápido en arm64 → amd64)
kamal build --remote
```

### 3. Deploy

```bash
# Deploy básico
kamal deploy

# Deploy con force (recreate containers)
kamal deploy --force

# Deploy a un servidor específico
kamal deploy -r web
```

### 4. Verificar

```bash
# Ver logs en tiempo real
kamal logs -f

# Ver logs de un contenedor específico
kamal logs -r job -f

# Ver estado de servicios
kamal app show
```

---

## 🛠️ Comandos Kamal

| Comando | Descripción |
|---------|-------------|
| `kamal deploy` | Desplegar aplicación |
| `kamal build` | Construir imagen Docker |
| `kamal logs` | Ver logs del contenedor |
| `kamal ssh` | SSH al servidor |
| `kamal app show` | Mostrar estado de la app |
| `kamal configure` | Configurar secretos |
| `kamal ssl` | Configurar SSL (Let's Encrypt) |

---

## ⚙️ Configuración de Rails para Producción

### `config/environments/production.rb`

```ruby
Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  
  # Serve static files
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control': 'public, max-age=3600'
  }
  
  # Compress responses
  config.force_ssl = true
  config.ssl_options = { hsts: { expires: 1.year, preload: true } }
  
  # Lograge for structured logging
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  
  # Perform less aggressive checks on trusted traffic
  config.load_defaults 8.1
end
```

---

## 🗄️ Base de Datos en Producción

### Configuración con Múltiples Bases de Datos

```yaml
# config/database.yml
production:
  primary: &primary_production
    adapter: postgresql
    host: <%= ENV['POSTGRES_HOST'] || 'db' %>
    username: <%= ENV['POSTGRES_USER'] %>
    password: <%= ENV['POSTGRES_PASSWORD'] %>
    database: <%= ENV['POSTGRES_DB'] %>

  cache:
    <<: *primary_production
    database: <%= ENV['POSTGRES_DB_CACHE'] || 'sale_point_production_cache' %>
    migrations_paths: db/cache_migrate

  queue:
    <<: *primary_production
    database: <%= ENV['POSTGRES_DB_QUEUE'] || 'sale_point_production_queue' %>
    migrations_paths: db/queue_migrate

  cable:
    <<: *primary_production
    database: <%= ENV['POSTGRES_DB_CABLE'] || 'sale_point_production_cable' %>
    migrations_paths: db/cable_migrate
```

### Migraciones

```bash
# Ejecutar migraciones en producción
RAILS_ENV=production bundle exec rails db:migrate

# Revertir migración
RAILS_ENV=production bundle exec rails db:rollback

# Reset base de datos
RAILS_ENV=production bundle exec rails db:reset
```

---

## 💾 Assets Precompilation

```bash
# Precompilar assets
RAILS_ENV=production bundle exec rails assets:precompile

# Limpiar assets antiguos
RAILS_ENV=production bundle exec rails assets:clean

# Ver assets compilados
ls -la public/assets/
```

---

## 📊 Monitoreo y Logging

### Sidekiq Web UI

```yaml
# En routes.rb (producción con autenticación)
authenticate :user, ->(u) { u.admin? } do
  mount Sidekiq::Web => '/sidekiq'
end
```

### Mission Control Jobs

```yaml
# En routes.rb
authenticate :user, ->(u) { u.admin? } do
  mount MissionControl::Jobs::Engine => '/jobs'
end
```

### Logs

```bash
# Ver logs de Rails
tail -f log/production.log

# Logs con Kamal
kamal logs -f --tail 100

# Parsear logs JSON con lograge
cat log/production.log | jq .
```

---

## 🔒 Seguridad en Producción

### Variables de Entorno Requeridas

```bash
# Rails
RAILS_MASTER_KEY=<32-character-key>
RAILS_LOG_LEVEL=info

# Database
POSTGRES_HOST=db.example.com
POSTGRES_USER=sale_point
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DB=sale_point_production

# Redis (para Kredis/Solid Queue)
REDIS_URL=redis://:password@redis:6379

# Sidekiq
SIDEKIQ_CONCURRENCY=5
```

### HTTPS y SSL

```bash
# Configurar SSL automáticamente
kamal ssl init domain.com

# Forzar SSL en Rails
# config/environments/production.rb
config.force_ssl = true
```

---

## 🔄 CI/CD con Kamal

### GitHub Actions (ejemplo)

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy with Kamal
        env:
          KAMAL_REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
          RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
        run: |
          gem install kamal
          kamal deploy
```

---

## 📈 Escalabilidad

### Vertical Scaling

```yaml
# Aumentar recursos en Kamal
env:
  clear:
    WEB_CONCURRENCY: 4
    WEB_TIMEOUT: 120
    SOLID_QUEUE_IN_PUMA: true
    JOB_CONCURRENCY: 3
```

### Horizontal Scaling

```yaml
# Añadir más servidores web
servers:
  web:
    - web1.example.com
    - web2.example.com
    - web3.example.com
```

---

## 🚨 Solución de Problemas

### Error: Database connection failed

```bash
# Verificar conexión
kamal ssh -c "nc -zv db 5432"

# Ver logs del contenedor db
docker logs sale_point-db
```

### Error: Assets compilation failed

```bash
# Ver logs del build
kamal build --verbose

# Verificar Node.js version
kamal ssh -c "node --version"
```

### Error: RAILS_MASTER_KEY not set

```bash
# Configurar clave
kamal env set RAILS_MASTER_KEY -s
```

### Error: Container crashes

```bash
# Ver logs en tiempo real
kamal logs -f

# Ver estado del contenedor
docker ps -a | grep sale_point
```

---

## 📋 Checklist de Producción

- [ ] `RAILS_MASTER_KEY` configurado
- [ ] Base de datos PostgreSQL accesible
- [ ] Redis disponible
- [ ] Dominio configurado con SSL
- [ ] Correo SMTP configurado
- [ ] Asset host configurado (si CDN)
- [ ] Error tracking configurado (ej. Sentry)
- [ ] Backups configurados
- [ ] Monitoring configurado
- [ ] Log rotation configurado