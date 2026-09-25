# Modelos del Sistema

Documentación detallada de todos los modelos en NEXO POS.

---

## 👤 Modelo User

**Archivo:** `app/models/user.rb`

### Asociaciones

```ruby
belongs_to :language, optional: true
has_many :user_roles, dependent: :destroy
has_many :system_roles, through: :user_roles
has_many :dashboard_preferences, dependent: :destroy
has_many :conversation_participants, dependent: :destroy
has_many :conversations, through: :conversation_participants
has_many :messages, dependent: :destroy
```

### Enums

```ruby
enum :user_type, {
  employee: 'employee',
  customer: 'customer',
  supplier: 'supplier'
}, validate: true

enum :status, {
  active: 'active',
  suspended: 'suspended',
  blocked: 'blocked',
  deleted: 'deleted'
}, validate: true
```

### Validaciones

```ruby
validates :email, presence: true, uniqueness: { case_sensitive: false }
validates :user_type, presence: true
validates :status, presence: true
validates :theme, presence: true, inclusion: { in: Theme.ids }
```

### Métodos Importantes

| Método | Descripción |
|--------|-------------|
| `admin?` | Verifica si el usuario es administrador (super_admin o administrator) |
| `role?(role_code, branch: nil)` | Verifica si el usuario tiene un rol específico |
| `initials` | Devuelve las iniciales del usuario |
| `display_name` | Nombre para mostrar (username o initials) |
| `broadcast_notifications_refresh` | Actualiza notificaciones en tiempo real |
| `online?` | Verifica si el usuario está online |
| `self.online_user_ids` | Devuelve IDs de usuarios online |

### Mecanismo de Autenticación

Usa Devise con módulos:
- `:database_authenticatable` - Autenticación con correo/contraseña
- `:registerable` - Registro de usuarios
- `:session_limitable` - Límite de sesiones
- `:recoverable` - Recuperación de contraseña
- `:rememberable` - Recordar sesión
- `:validatable` - Validaciones de email y contraseña
- `:trackable` - Tracking de sesiones

---

## 📦 Modelo Product

**Archivo:** `app/models/product.rb`

### Asociaciones

```ruby
belongs_to :category, optional: true
belongs_to :sat_unit_key, optional: true
belongs_to :sat_tax, optional: true
has_one_attached :image
```

### Enums

```ruby
enum :status, {
  active: 'active',
  inactive: 'inactive'
}, validate: true, default: 'active'
```

### Validaciones

```ruby
validates :code, presence: true,
                 uniqueness: { case_sensitive: false },
                 length: { maximum: 50 },
                 format: { with: /\A[A-Za-z0-9\-_]+\z/, message: :invalid_format }

validates :name, presence: true, length: { maximum: 100 }
validates :description, length: { maximum: 500 }, allow_blank: true
validates :sku, uniqueness: { case_sensitive: false, allow_nil: true, if: -> { sku.present? } }
validates :barcode, uniqueness: { case_sensitive: false, allow_nil: true, if: -> { barcode.present? } }
validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
validates :min_stock, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
validates :max_stock, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
validates :featured, inclusion: { in: [true, false] }
validates :view_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
```

### Scopes

```ruby
scope :not_deleted, -> { where(deleted_at: nil) }
scope :available, -> { where(status: :active) }
scope :with_category, -> { includes(:category) }
scope :featured, -> { where(featured: true) }
scope :by_slug, ->(slug) { where(slug: slug) }
scope :sorted_by_position, -> { order(position: :asc, name: :asc) }
```

### Callbacks

```ruby
before_validation :set_defaults, if: :new_record?
before_validation :set_slug, if: -> { name.present? && slug.blank? }
```

### Métodos Personalizados

```ruby
def low_stock?
  return false if min_stock.nil? || min_stock.zero?
  stock <= min_stock
end

def increment_view_count!
  # rubocop:disable-next Rails/SkipsModelValidations
  increment!(:view_count)
end

def to_param
  slug.presence
end
```

---

## 📂 Modelo Category

**Archivo:** `app/models/category.rb`

### Atributos

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `code` | string | Código único (máx 20 chars) |
| `name` | string | Nombre (máx 50 chars) |
| `description` | text | Descripción (máx 500 chars) |
| `status` | enum | Estado: active/inactive |
| `deleted_at` | datetime | Soft delete |

### Validaciones

```ruby
validates :name, presence: true, length: { maximum: 50 }
validates :code, presence: true, uniqueness: true,
                 length: { maximum: 20 },
                 format: { with: /\A[a-z0-9_]+\z/ }
validates :description, length: { maximum: 500 }, allow_blank: true
```

### Scopes

```ruby
scope :available, lambda { where(status: :active) }
scope :not_deleted, lambda { where(deleted_at: nil) }
```

---

## 🌐 Modelo Language

**Archivo:** `app/models/language.rb`

### Atributos

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `code` | string | Código ISO 639-1 (2 chars) |
| `name` | string | Nombre del idioma |
| `flag_iso` | string | Código ISO país para bandera (2 chars) |
| `status` | enum | Estado |
| `deleted_at` | datetime | Soft delete |

### Asociaciones

```ruby
has_many :users, dependent: :nullify
has_many :translates, dependent: :destroy
```

### Validaciones

```ruby
validates :code, presence: true, uniqueness: true, length: { maximum: 2 }
validates :name, presence: true
validates :flag_iso, presence: true, length: { is: 2 }
```

### Scopes

```ruby
scope :available, lambda { where(status: :active, deleted_at: nil) }
scope :not_deleted, lambda { where(deleted_at: nil) }
```

### Métodos

```ruby
def flag_url(size = '64x48')
  "https://flagcdn.com/#{size}/#{flag_iso}.png"
end

def flag_srcset
  ["#{flag_url('80x60')} 2x", "#{flag_url('96x72')} 3x"].join(', ')
end
```

---

## 👑 Modelo SystemRole

**Archivo:** `app/models/system_role.rb`

### Enums

```ruby
enum :role_type, { system: 'system', branch: 'branch' }
enum :status, { active: 'active', inactive: 'inactive', deprecated: 'deprecated' }
```

### Asociaciones

```ruby
has_many :user_roles, dependent: :restrict_with_exception
has_many :users, through: :user_roles
```

### Scopes

```ruby
scope :system_roles, -> { where(role_type: 'system') }
scope :branch_roles, -> { where(role_type: 'branch') }
scope :not_deleted, -> { where(deleted_at: nil) }
scope :deprecated, -> { with_deleted.where(status: 'deprecated') }
scope :available, -> { where(deleted_at: nil).where.not(status: 'deprecated') }
```

---

## 🔗 Modelo UserRole (Join Table)

**Archivo:** `app/models/user_role.rb`

### Asociaciones

```ruby
belongs_to :user
belongs_to :system_role
belongs_to :branch, optional: true
```

### Validaciones

```ruby
validate :branch_role_requires_branch
validate :global_role_cannot_have_branch

validates :user_id, uniqueness: {
  scope: %i[system_role_id branch_id],
  conditions: -> { where(deleted_at: nil) }
}
```

### Métodos Privados

```ruby
def branch_role_requires_branch
  return unless system_role&.branch? && branch_id.blank?
  errors.add(:branch, 'is required for branch roles')
end

def global_role_cannot_have_branch
  return unless system_role&.system? && branch_id.present?
  errors.add(:branch, 'must be blank for system roles')
end
```

---

## 📍 Modelo Branch

**Archivo:** `app/models/branch.rb`

### Asociaciones

```ruby
has_many :user_roles, dependent: :restrict_with_exception
has_many :users, through: :user_roles
```

### Atributos

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre de la sucursal |
| `address` | string | Dirección |
| `phone` | string | Teléfono |
| `status` | boolean | Estado activo/inactivo |
| `deleted_at` | datetime | Soft delete |

---

## 💬 Modelos de Conversación y Mensajes

### Modelo Conversation

**Archivo:** `app/models/conversation.rb`

```ruby
enum :conversation_type, { direct: 'direct' }, default: 'direct'
```

### Modelo Message

**Archivo:** `app/models/message.rb`

```ruby
belongs_to :conversation
belongs_to :user
```

---

## 📧 Modelos de Notificaciones

### Modelo Noticed::Notification

Usan el gem `noticed` para notificaciones en tiempo real.

**Modelos de Notificación:**
- `ProductNotification` - Notificaciones de productos
- `CategoryNotification` - Notificaciones de categorías
- `LanguageNotification` - Notificaciones de idiomas

---

## 💰 Modelos SAT (México)

### Modelo SatTax

**Archivo:** `app/models/sat_tax.rb`

**Enums:**
```ruby
TAX_TYPES = %w[transfer withheld].freeze
FACTOR_TYPES = %w[rate quota exempt].freeze
APPLIES_TO = %w[product service both].freeze
```

### Modelo SatUnitKey

**Archivo:** `app/models/sat_unit_key.rb`

Atributos: `code` (5 chars), `description`, `symbol`

### Modelo SatCurrency

**Archivo:** `app/models/sat_currency.rb`

Atributos: `code` (3 chars ISO), `description`, `symbol`, `decimals`, `variation_percentage`

---

## 📊 Modelos de Dashboard

### Modelo DashboardPreference

**Archivo:** `app/models/dashboard_preference.rb`

### Atributos

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `user_id` | bigint | Relación con User |
| `widget_id` | string | ID del widget |
| `grid_type` | string | Tipo de grid |
| `position_x` | integer | Posición X |
| `position_y` | integer | Posición Y |
| `width` | integer | Ancho |
| `height` | integer | Alto |

---

## 📋 Resumen de Modelos

| Modelo | Tabla | Clave Primaria | Soft Delete |
|--------|-------|----------------|-------------|
| User | users | id | ✅ |
| Product | products | id | ✅ |
| Category | categories | id | ✅ |
| Language | languages | id | ✅ |
| SystemRole | system_roles | id | ✅ |
| UserRole | user_roles | id | ✅ |
| Branch | branches | id | ✅ |
| Conversation | conversations | id | ✅ |
| Message | messages | id | ✅ |
| DashboardPreference | dashboard_preferences | id | ✅ |
| SatTax | sat_taxes | code | ✅ |
| SatUnitKey | sat_unit_keys | code | ✅ |
| SatCurrency | sat_currencies | code | ✅ |
| SatFiscalRegime | sat_fiscal_regimes | code | ✅ |
| SatBank | sat_banks | code | ✅ |
| SatPaymentMethod | sat_payment_methods | code | ✅ |
| SatPaymentMethodType | sat_payment_method_types | code | ✅ |
| SatMonth | sat_months | code | ✅ |
| DemoRequest | demo_requests | id | ✅ |
| Translate | translates | id | ✅ |