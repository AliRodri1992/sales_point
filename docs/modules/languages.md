# Idiomas

Gestión de idiomas y traducciones en NEXO POS.

---

## 🌐 Modelo Language

**Ubicación:** `app/models/language.rb`

### Atributos

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `code` | string | ✅ | Código ISO 639-1 (2 caracteres) |
| `name` | string | ✅ | Nombre del idioma |
| `flag_iso` | string | ✅ | Código ISO país para bandera (2 caracteres) |
| `status` | string | ✅ | Estado: active/inactive |
| `deleted_at` | datetime | ❌ | Soft delete |

### Ejemplos de Idiomas Configurados

| Código | Nombre | Flag | Estado |
|--------|--------|------|--------|
| `es` | Español | ES | Activo |
| `en` | English | US/GB | Activo |
| `ko` | 한국어 | KR | Activo |

---

## 🔗 Asociaciones

```ruby
class Language < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :translates, dependent: :destroy
end

# En User
belongs_to :language, optional: true
```

---

## 🎨 Métodos Útiles

### `flag_url`

Devuelve la URL de la bandera desde flagcdn.com

```ruby
def flag_url(size = '64x48')
  "https://flagcdn.com/#{size}/#{flag_iso}.png"
end

# Ejemplos:
language.flag_url          # "https://flagcdn.com/64x48/es.png"
language.flag_url('32x24')  # "https://flagcdn.com/32x24/es.png"
```

### `flag_srcset`

Devuelve srcset para responsive images

```ruby
def flag_srcset
  [
    "#{flag_url('80x60')} 2x",
    "#{flag_url('96x72')} 3x"
  ].join(', ')
end
```

---

## 📝 Validaciones

```ruby
validates :code, presence: true, uniqueness: true, length: { maximum: 2 }
validates :name, presence: true
validates :flag_iso, presence: true, length: { is: 2 }
```

---

## 🔄 Scopes

```ruby
scope :available, lambda { where(status: :active, deleted_at: nil) }
scope :not_deleted, lambda { where(deleted_at: nil) }
```

---

## 🌍 Sistema de Idiomas

### Idiomas Disponibles

```ruby
# config/application.rb
config.i18n.default_locale = :es
config.i14n.available_locales = %i[en es ko]
```

### Archivos de Traducción

```text
config/locales/
├── en.yml           # Inglés
├── es.yml           # Español (predeterminado)
├── ko.yml           # Coreano
└── devise.*.yml     # Traducciones Devise
```

---

## 🔄 Selector de Idioma

### Endpoint

```
PATCH /language
```

### Implementación

```ruby
# app/controllers/languages_controller.rb
def update
  session[:language_id] = params[:id]
  redirect_back_or_to(root_path)
end
```

### Uso en Vistas

```erb
<%= form_with url: language_path, method: :patch do |f| %>
  <%= f.collection_select :id, Language.available, :id, :name do |l| %>
    <%= content_tag :option, l.name, value: l.id, data: { flag: l.flag_iso } %>
  <% end %>
<% end %>
```

---

## 📡 Broadcast en Tiempo Real

Al cambiar idioma, se actualiza el selector:

```ruby
# app/controllers/admin/languages_controller.rb
def broadcast_language_selector
  current = helpers.current_language
  html = render_to_string(
    partial: 'admin/shared/language_selector_content',
    formats: [:html],
    locals: { current: }
  )
  Turbo::StreamsChannel.broadcast_update_to(
    'language_selector',
    target: 'language_selector_content',
    html: html
  )
end
```

---

## 🛠️ Rutas Disponibles

| Método | Endpoint | Acción | Descripción |
|--------|----------|--------|-------------|
| GET | `/admin/languages` | `index` | Lista idiomas |
| GET | `/admin/languages/new` | `new` | Formulario nuevo |
| POST | `/admin/languages` | `create` | Crear idioma |
| GET | `/admin/languages/:id/edit` | `edit` | Formulario editar |
| PATCH | `/admin/languages/:id` | `update` | Actualizar |
| DELETE | `/admin/languages/:id` | `destroy` | Eliminar |
| GET | `/admin/languages/content` | `content` | API para selector |
| PATCH | `/language` | `update` | Cambiar idioma actual |

---

## 🧪 Tests

```ruby
# spec/models/language_spec.rb
describe Language do
  it { should validate_presence_of(:code) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:flag_iso) }
  it { should validate_length_of(:flag_iso).is_equal_to(2) }

  describe '#flag_url' do
    it 'returns correct URL' do
      language = build(:language, flag_iso: 'mx')
      expect(language.flag_url).to eq('https://flagcdn.com/64x48/mx.png')
    end
  end
end
```