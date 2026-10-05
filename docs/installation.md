# Instalación

Guía paso a paso para instalar y configurar NEXO POS.

---

## 🚀 Requisitos Previos

### Software necesario

| Software | Versión | Uso |
|----------|---------|-----|
| **Ruby** | 3.3.6 | Lenguaje backend |
| **Rails** | 8.1.3 | Framework web |
| **PostgreSQL** | 15+ | Base de datos |
| **Node.js** | 18+ | JavaScript/Node |
| **Yarn** | 1.22+ | Package manager |
| **Docker** | 24+ | (Opcional) Contenedores |

---

## 📦 Opción 1: Instalación con Docker (Recomendado)

### 1. Preparar archivos de entorno

```bash
# Copiar archivo de configuración
cp .env.example .env 2>/dev/null || echo "Crear .env manualmente"
```

### 2. Crear .env

```bash
# .env
POSTGRES_USER=sale_point
POSTGRES_PASSWORD=secure_password_change_me
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=sale_point_development
RAILS_MASTER_KEY=$(cat config/master.key)
```

### 3. Levantar contenedores

```bash
# Desarrollo
docker-compose -f docker-compose.dev.yml up -d

# Verificar que todo esté corriendo
docker-compose -f docker-compose.dev.yml ps
```

### 4. Configurar base de datos

```bash
# Ejecutar migraciones
docker-compose -f docker-compose.dev.yml exec web bin/rails db:create db:migrate

# (Opcional) Seed de datos
docker-compose -f docker-compose.dev.yml exec web bin/rails db:seed
```

### 5. Precompilar assets

```bash
docker-compose -f docker-compose.dev.yml exec web bin/rails assets:precompile
```

### 6. Iniciar servidor

```bash
# Servidor Rails
docker-compose -f docker-compose.dev.yml exec web bin/rails server -b 0.0.0.0 -p 3000

# Build de JS (en otra terminal)
docker-compose -f docker-compose.dev.yml exec web yarn build:js:watch

# Build de CSS (en otra terminal)
docker-compose -f docker-compose.dev.yml exec web yarn build:css:watch
```

### 7. Acceder a la aplicación

```
http://localhost:3000
```

---

## 💻 Opción 2: Instalación Local (Sin Docker)

### 1. Clonar el repositorio

```bash
git clone [url-del-repositorio] sale_point
cd sale_point
```

### 2. Instalar Ruby y Rails

```bash
# Usar rbenv o rvm
rbenv install 3.3.6
rbenv local 3.3.6

# Instalar dependencias
bundle install
```

### 3. Configurar base de datos PostgreSQL

```bash
# Crear usuario y base de datos
sudo -u postgres createuser -s sale_point
sudo -u postgres createdb sale_point_development

# Configurar database.yml
echo "POSTGRES_USER=sale_point" >> .env
echo "POSTGRES_PASSWORD=" >> .env
echo "POSTGRES_DB=sale_point_development" >> .env
```

### 4. Configurar variables de entorno

```bash
# Crear archivo .env
echo "POSTGRES_USER=sale_point" >> .env
echo "POSTGRES_PASSWORD=" >> .env
echo "POSTGRES_DB=sale_point_development" >> .env
echo "RAILS_MASTER_KEY=$(cat config/master.key)" >> .env
```

### 5. Preparar base de datos

```bash
bin/rails db:create
bin/rails db:migrate
# bin/rails db:seed  # Si existe seeds.rb
```

### 6. Instalar dependencias frontend

```bash
# Instalar gems
bundle install

# Instalar npm packages
yarn install

# Precompilar assets
bin/rails assets:precompile
```

### 7. Iniciar el servidor

```bash
bin/rails server
```

### 8. Acceder a la aplicación

```
http://localhost:3000
```

---

## 🧪 Instalar Sidekiq (Opcional)

```bash
# Para background jobs
bundle exec sidekiq

# O usar foreman para múltiples procesos
foreman start -f Procfile.dev
```

---

## 🧪 Ejecutar Tests

```bash
# Todos los tests
bundle exec rspec

# Tests de modelo
bundle exec rspec spec/models/

# Tests de request
bundle exec rspec spec/requests/

# Tests con output detallado
bundle exec rspec --format documentation

# Ver cobertura
bundle exec rspec
open coverage/index.html
```

---

## 🔧 Comandos Útiles

### Rails

```bash
bin/rails console       # Consola interactiva
bin/rails db:migrate    # Ejecutar migraciones
bin/rails routes          # Ver rutas
bin/rails generate model  # Generar modelo
bin/rails g controller    # Generar controlador
```

### Git

```bash
git status
git add .
git commit -m "Mensaje"
git push origin feature/nuevo-feature
```

### Debug

```bash
# Ver logs en tiempo real
tail -f log/development.log

# Reiniciar servidor
Ctrl+C
bin/rails server

# Limpiar cache
bin/rails tmp:clear
```

---

## 🛠️ Configuración de Desarrollo

### For Development

```bash
# Configuración recomendada
RAILS_ENV=development
DEBUG=true
```

### Habilitar logging SQL

```ruby
# En config/environments/development.rb
config.log_level = :debug
config.log_tags = [:request_id]
```

---

## 🔐 Primer Usuario Admin

### Registro

1. Acceder a `http://localhost:3000/users/sign_up`
2. Crear cuenta (el primer usuario será automáticamente admin)
3. O usar consola:

```bash
bin/rails console
user = User.create!(email: 'admin@example.com', password: 'password')
user.update!(user_type: 'employee', status: 'active')
user.user_roles.create!(system_role: SystemRole.system_roles.find_by(code: 'administrator'))
```

---

## 🚨 Solución de Problemas Comunes

### Error: `can't find gem 'pg'`

```bash
gem install pg
bundle install
```

### Error: `Webpack isn't configured`

```bash
yarn install
yarn build:js
```

### Error: `RAILS_MASTER_KEY not set`

```bash
cat config/master.key
export RAILS_MASTER_KEY=$(cat config/master.key)
```

### Error: `PG::ConnectionBad`

```bash
# Verificar PostgreSQL está corriendo
lsof -i :5432

# Verificar credenciales
psql -U sale_point -d sale_point_development
```

### Error: `Permission denied`

```bash
# Dar permisos correctos
chmod -R 755 .
```

---

## 📋 Verificación de Instalación

```bash
# Verificar versiones
ruby -v      # => ruby 3.3.6
rails -v     # => Rails 8.1.3
psql --version  # => PostgreSQL 15.x
node -v      # => v18.x
yarn -v      # => 1.22.x

# Verificar bundles
bundle exec rspec --version  # => 3.x
```