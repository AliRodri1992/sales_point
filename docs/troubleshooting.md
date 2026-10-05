# Troubleshooting

Guía de solución de problemas comunes en NEXO POS.

---

## 🚨 Problemas Comunes

### 1. Error de Conexión a Base de Datos

**Mensaje de error:**
```
PG::ConnectionBad: could not connect to server: Connection refused
```

**Causas posibles:**
- PostgreSQL no está ejecutándose
- Credenciales incorrectas
- Host incorrecto

**Solución:**

```bash
# Verificar que PostgreSQL está ejecutándose
docker ps | grep postgres

# Conectar a la base de datos
docker-compose exec db psql -U sale_point -d sale_point_development

# Verificar variables de entorno
echo $POSTGRES_HOST
echo $POSTGRES_USER
echo $POSTGRES_PASSWORD

# Ejecutar migraciones
bin/rails db:migrate
```

---

### 2. Error de Webpack/Esbuild

**Mensaje de error:**
```
Webpack isn't configured for this project yet.
```

**Solución:**

```bash
# Instalar dependencias
yarn install

# Compilar assets
yarn build:js
yarn build:css

# Para desarrollo (watch mode)
yarn build:js:watch
yarn build:css:watch
```

---

### 3. Error de Secret Key Base

**Mensaje de error:**
```
ActionController::InvalidAuthenticityToken
```

**Solución:**

```bash
# Verificar RAILS_MASTER_KEY
echo $RAILS_MASTER_KEY

# Regenerar key (si es necesario)
bin/rails secret

# Verificar credentials
bin/rails credentials:show
```

---

### 4. Error de Rutas Devise

**Mensaje de error:**
```
No route matches [GET] "/users/sign_in"
```

**Solución:**

```bash
# Verificar routes
bin/rails routes | grep devise

# Reiniciar servidor
bin/rails server

# Verificar config/routes.rb
# Asegurarse de tener:
# devise_for :users
```

---

## 🐳 Problemas con Docker

### Container se reinicia repetidamente

```bash
# Ver logs del contenedor
docker-compose logs web

# Ver estado del contenedor
docker-compose ps

# Verificar recursos del sistema
docker system df

# Limpiar contenedores huérfanos
docker system prune -f
```

### Error de permisos en volúmenes

```bash
# Verificar permisos
ls -la tmp/storage  # Para test storage
ls -la storage       # Para Active Storage

# Arreglar permisos
sudo chown -R $USER:$USER storage
sudo chown -R $USER:$USER tmp/storage
```

---

## 🧪 Problemas con Tests

### Fallan tests por DatabaseCleaner

```ruby
# spec/rails_helper.rb
config.before(:suite) do
  DatabaseCleaner.strategy = :transaction
  DatabaseCleaner.clean_with(:truncation)
end

# Si persiste el problema:
# Usar.truncation en lugar de :transaction
DatabaseCleaner.strategy = :truncation
```

### Error con FactoryBot

```bash
# Limpiar caché
bundle exec spring stop

# Reiniciar
bin/rails test
```

---

## 🛠️ Debugging

### Console interactiva

```bash
# Iniciar consola
bin/rails console

# Ejemplos de debugging
User.find_by(email: 'test@example.com')
Product.joins(:category).where(categories: { status: 'active' })
ActiveRecord::Base.logger = Logger.new(STDOUT)  # Log SQL
```

### Ver logs en tiempo real

```bash
# Logs de Rails
tail -f log/development.log

# Logs con Colores
echo 'lograge.enabled = true' >> config/environments/development.rb
```

---

## 🔧 Problemas de Precompilación de Assets

### Error de asset missing

```bash
# Limpiar assets
RAILS_ENV=production rake assets:clobber

# Precompilar
RAILS_ENV=production rake assets:precompile
```

### Error de webpacker

```bash
# Verificar node version
node --version

# Reinstall dependencies
rm -rf node_modules
yarn install
```

---

## 📊 Problemas con Sidekiq

### Sidekiq no procesa jobs

```bash
# Verificar que Redis está ejecutándose
docker-compose exec redis redis-cli ping

# Verificar Sidekiq UI
# http://localhost:3000/sidekiq

# Reiniciar Sidekiq
bundle exec sidekiq -C config/sidekiq.yml
```

### Jobs se quedan en retry

```bash
# Ver jobs en retry
Sidekiq::RetrySet.new.map(&:klass)

# Reprocesar jobs fallidos
Sidekiq::RetrySet.new.each(&:retry)
```

---

## 🔐 Problemas de Autenticación

### Usuario no puede iniciar sesión

```ruby
# Verificar usuario
User.find_by(email: 'user@example.com')
  .tap { |u| u.update(activate: true) if u.respond_to?(:activate) }

# Verificar contraseña
user.valid_password?('password123')

# Resetear contraseña
user.reset_password_token = nil
user.reset_password_sent_at = nil
user.save!
```

### Session expirada inesperadamente

```ruby
# Verificar timeoutable config
# Si está habilitado, verificar intervalo
Devise.timeout_in = 30.minutes

# Limpiar session cookie
cookies.delete(:user_id)
```

---

## 🌐 Problemas de Internacionalización

### Traducciones no se cargan

```bash
# Verificar locales disponibles
I18n.available_locales

# Verificar archivo de traducción
Rails.root.join('config', 'locales', 'es.yml')

# Verificar claves
I18n.t('admin.products.index.title', locale: :es)
```

---

## 📱 Problemas con Turbo Streams

### Updates no llegan al cliente

```ruby
# Verificar broadcast
Turbo::StreamsChannel.broadcast_update_to(
  'products_catalog',
  target: 'admin_products_list',
  html: rendered_html
)

# Verificar turbo_frame_tag en vista
<%= turbo_frame_tag "admin_products_list" %>
```

---

## 🔍 Debugging de Rutas

### Ver todas las rutas

```bash
# Listar rutas
bin/rails routes

# Filtrar rutas
bin/rails routes | grep products

# Ver rutas de un namespace
bin/rails routes | grep admin
```

### Ver params recibidos

```ruby
# En controller
def create
  Rails.logger.debug "Params: #{params.inspect}"
  # ...
end
```

---

## 📈 Problemas de Rendimiento

### Query lento

```ruby
# Habilitar logging SQL
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Usar eager loading
Product.includes(:category, :sat_tax).all

# Ver queries N+1
# Usar bullet gem o rack-mini-profiler
```

---

## 📦 Problemas de Deploy

### Error en Kamal deploy

```bash
# Ver logs detallados
kamal deploy --verbose

# Ver estado de contenedores
kamal app show

# Reconstruir imagen
kamal build --force

# Reiniciar servicios
kamal app restart
```

---

## 🔧 Comandos Útiles de Diagnóstico

```bash
# Ver versiones
ruby -v
rails -v
bundle -v

# Ver dependencias
bundle list

# Ver errores de RuboCop
bundle exec rubocop --format progress
bundle exec rubocop --auto-correct

# Verificar YAML
bundle exec ruby -e "require 'yaml'; YAML.load_file('config/database.yml')"

# Verificar migraciones
bin/rails db:migrate:status
```

---

## 📊 Monitoreo de Errores

### Configurar env para debugging

```bash
# Development
RAILS_ENV=development
RACK_ENV=development
DEBUG=true

# Ver logs con colores
tail -f log/development.log | ccze -A
```

---

## 🆘 Cuándo Pedir Ayuda

Si has intentado solucionar el problema y persiste, reunir la siguiente información:

1. **Mensaje de error completo**
2. **Backtrace/full stack trace**
3. **Versión de Ruby/Rails**
4. **Comando que falla**
5. **Últimos cambios realizados**
6. **Entorno (development/production/test)**

```bash
# Recopilar información
ruby -v
rails -v
bundle list | grep -E "(rails|devise|sidekiq)"
bin/rails runner "puts Rails.env"
```