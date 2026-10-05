# Seguridad

Guía de seguridad de NEXO POS.

---

## 🔒 Principios de Seguridad

NEXO POS implementa múltiples capas de seguridad para proteger datos sensibles y prevenir accesos no autorizados.

---

## 🛡️ Capas de Seguridad

### 1. Autenticación

```
┌─────────────────────────────────────────────────────┐
│                    Devise + devise-security         │
│  - Email/Password authentication                   │
│  - Session limitable (límite de sesiones)          │
│  - Recoverable (recuperación de password)          │
│  - Rememberable (Remember me)                       │
│  - Trackable (tracking de login)                    │
└─────────────────────────────────────────────────────┘
```

### 2. Control de Acceso

```
┌─────────────────────────────────────────────────────┐
│                     Roles y Permisos                │
│  - System roles (globales)                          │
│  - Branch roles (por sucursal)                      │
│  - user_roles join table (asignaciones)             │
│  - Admin check en controllers                       │
└─────────────────────────────────────────────────────┘
```

### 3. Protección de Aplicación

```
┌─────────────────────────────────────────────────────┐
│                 Rack::Attack + Secure Headers       │
│  - Rate limiting por IP (300 req/5min)             │
│  - Rate limiting login (5 intentos/60s)             │
│  - Rate limiting admin (10 req/1min)                │
│  - CSP headers configurados                       │
│  - CSRF protection activa                           │
└─────────────────────────────────────────────────────┘
```

---

## 🔐 Configuración de Seguridad

### Devise Security

**Archivo:** `config/initializers/devise_security.rb`

```ruby
Devise.setup do |config|
  # RECOMENDADO: Habilitar estas opciones en producción
  
  # Límite de sesiones por usuario
  # config.session_limitable = true
  
  # Complejidad de contraseña
  # config.password_complexity = { digit: 1, lower: 1, symbol: 1, upper: 1 }
  
  # Expiración de contraseña
  # config.expire_password_after = 90.days
  
  # Archivar contraseñas
  # config.password_archiving_count = 5
  
  # Rechazar contraseñas antiguas
  # config.deny_old_passwords = 3
  
  # Validación de email
  # config.email_validation = true
end
```

### Rack::Attack

**Archivo:** `config/initializers/rack_attack.rb`

```ruby
class Rack::Attack
  # Throttle por IP general
  throttle("requests by IP", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle para login
  throttle("login attempts", limit: 5, period: 60.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      "#{req.ip}:#{req.params['email']}"
    end
  end

  # Throttle para rutas admin
  throttle("admin abuse", limit: 10, period: 1.minute) do |req|
    req.path.include?("admin") ? req.ip : nil
  end
end
```

---

## 🔑 Credenciales

### Rails Credentials

**Archivo:** `config/credentials.yml.enc` (encriptado)

```bash
# Editar credentials
bin/rails credentials:edit

# Ver master key
cat config/master.key
```

### Variables de Entorno Sensibles

```bash
# Requeridas
POSTGRES_PASSWORD=<strong-password>
RAILS_MASTER_KEY=<32-char-key>

# Opcionales
SECRET_KEY_BASE=<long-random-string>
```

---

## 🛡️ HTTP Security Headers

**Archivo:** `config/initializers/secure_headers.rb`

```ruby
# Headers de seguridad configurados
SecureHeaders::Configuration.default do |config|
  config.default_src :none
  config.script_src :self
  config.style_src :self, :unsafe_inline
  config.img_src :self, :data
  config.font_src :self
  config.object_src :none
  config.frame_ancestors :none
  config.content_security_policy_nonce_generator = -> { SecureRandom.base64(16) }
end
```

---

## 🍪 Cookies Seguras

**Archivo:** `app/controllers/application_controller.rb`

```ruby
def set_action_cable_user_id_cookie
  return unless user_signed_in?
  return if cookies.signed[:user_id] == current_user.id

  cookies.signed[:user_id] = {
    value: current_user.id,
    httponly: true,      # No accesible por JavaScript
    same_site: :lax,     # Protección CSRF
    secure: Rails.env.production?  # HTTPS solo en prod
  }
end
```

---

## 🔐 Soft Delete (Paranoia)

]**Gem:** `paranoia`

Los siguientes modelos usan soft delete:

| Modelo | Tabla | Campo |
|--------|-------|-------|
| User | users | `deleted_at` |
| Product | products | `deleted_at` |
| Category | categories | `deleted_at` |
| Language | languages | `deleted_at` |
| Conversation | conversations | `deleted_at` |
| Message | messages | `deleted_at` |
| Branch | branches | `deleted_at` |

### Uso

```ruby
# En modelos
acts_as_paranoid

# En consultas
Product.with_deleted      # Incluye borrados
Product.not_deleted        # Solo activos
Product.only_deleted       # Solo borrados
```

---

## 🔍 Auditoría de Cambios

**Gem:** `paper_trail`

```ruby
# En modelos
class Product < ApplicationRecord
  has_paper_trail
end

# Consultar cambios
product.versions.last.user  # Usuario que hizo el cambio
product.versions.last.changes  # Cambios específicos
```

---

## 🔒 Protección contra Ataques Comunes

### SQL Injection

**Protegido por:** ActiveRecord (consultas parametrizadas)

```ruby
# ✅ CORRECTO
Product.where('name ILIKE :q', q: "%#{params[:search]}%")

# ❌ INCORRECTO (evitar)
Product.where("name ILIKE '%#{params[:search]}%'")
```

### XSS (Cross-Site Scripting)

**Protegido por:**
- Rails escape automático en vistas
- CSP headers
- `html_safe` solo cuando sea necesario

```erb
<%# ✅ Rails escapa automáticamente %>
<%= product.name %>

<%# ✅ Si necesitas HTML sin escapear %>
<%= safe_join([...]) %>
```

### CSRF (Cross-Site Request Forgery)

**Protegido por:**
- CSRF tokens en formularios
- `csrf_meta_tags` en layouts

```erb
<%= csrf_meta_tags %>
<%= csp_meta_tag %>
```

---

## 📊 Tracking de Sesiones

**Archivo:** `app/channels/application_cable/connection.rb`

```ruby
class Connection < ActionCable::Connection::Base
  identified_by :current_user

  def connect
    self.current_user = find_verified_user
  end

  def disconnect
    # Limpieza de recursos
  end

  private

  def find_verified_user
    user_id = cookies.signed[:user_id]
    return unless user_id

    User.find_by(id: user_id) || reject_unauthorized_connection
  end
end
```

---

## 🔐 Presencia de Usuarios Online

**Usando:** Kredis (Redis wrapper)

```ruby
# app/models/user.rb
ONLINE_USERS_KEY = 'online_users'.freeze

def online?
  self.class.online_user_ids.include?(id)
end

def self.online_user_ids
  Kredis.set(ONLINE_USERS_KEY).members.map(&:to_i)
end
```

---

## 📋 Auditoría de Seguridad

### Configuración Actual

| Característica | Estado | Comentario |
|----------------|--------|------------|
| HTTPS (Force SSL) | ⚠️ Configuración | En producción: `config.force_ssl = true` |
| HTTP Basic Auth | ❌ No implementado |  |
| Two-Factor Auth | ❌ No implementado |  |
| IP Whitelisting | ❌ No implementado |  |
| MFA | ❌ No implementado |  |
| Session Timeout | ❌ No implementado | Devise :timeoutable no configurado |
| Lockable | ❌ Comentado | Para bloquear cuentas tras intentos fallidos |

---

## 🔒 Recomendaciones para Producción

### Críticas (Deben implementarse)

1. **Habilitar force_ssl**
   ```ruby
   # config/environments/production.rb
   config.force_ssl = true
   ```

2. **Configurar timeoutable**
   ```ruby
   # En Devise config
   config.timeout_in = 30.minutes
   ```

3. **Habilitar lockable**
   ```ruby
   # Permite bloquear cuentas tras múltiples intentos fallidos
   config.lockable = true
   ```

### Recomendadas

4. **Habilitar devise-security completo**
   - password_complexity
   - expire_password_after
   - deny_old_passwords

5. **Implementar Pundit para autorización granular**
   ```ruby
   class ProductPolicy < ApplicationPolicy
     def update?
       user.admin? || record.owner == user
     end
   end
   ```

6. **Agregar confirmable para verificación de email**
   ```ruby
   # Requiere confirmar email antes de usar la cuenta
   ```

7. **Configurar Two-Factor Authentication**
   - Usar gem como `two-factor-authentication`

---

## 🚨 Alertas de Seguridad

### Rack::Attack Throttling

Cuando se excede el rate limit, se devuelve:

```
HTTP 429 Too Many Requests
Body: "Too many requests. Try again later."
```

### Manejo de Errores

```ruby
# config/initializers/error_handling.rb
Rails.application.config.exceptions_app = self.routes

# catchalla errores críticos
rescue_from StandardError, with: :internal_server_error
```

---

## 🛠️ Comandos de Seguridad

```bash
# Ejecutar brakeman (análisis de seguridad)
bundle exec brakeman -q

# Verificar dependencias con bundler-audit
bundle exec bundler-audit check --update

# Escanear con rubocop-Airbrake
bundle exec rubocop --only GitHub::Security

# Verificar fuerzas brutas en logs
grep "login" log/development.log
```

---

## 📋 Checklist de Seguridad Producción

Antes de desplegar a producción:

- [ ] `RAILS_MASTER_KEY` almacenada en secrets (no en código)
- [ ] `config.force_ssl = true` habilitado
- [ ] `config.hosts` configurado con dominios permitidos
- [ ] `SECRET_KEY_BASE` generado y almacenado en credentials
- [ ] Base de datos con contraseña fuerte
- [ ] Redis con autenticación
- [ ] CORS headers configurados correctamente
- [ ] Rate limiting verificado
- [ ] Logs no exponen datos sensibles
- [ ] Backup automático configurado
- [ ] SSL/TLS certificado válido