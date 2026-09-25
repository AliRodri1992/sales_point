# Categorías

Gestión de categorías de productos en NEXO POS.

---

## 📂 Modelo Category

**Ubicación:** `app/models/category.rb`

### Atributos

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `code` | string | ✅ | Código único de la categoría |
| `name` | string | ✅ | Nombre de la categoría |
| `description` | text | ❌ | Descripción de la categoría |
| `status` | string | ✅ | Estado: active/inactive |
| `deleted_at` | datetime | ❌ | Soft delete |

### Formato de Código

```ruby
# Formato: minúsculas, números, guion bajo
# Ejemplos válidos: supermarket, electronics_1, food2023
# Ejemplo inválido: SuperMarket! (espacio y caracteres especiales)
```

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

## 🔄 Asociaciones

```ruby
class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_exception
end

# En Product
belongs_to :category, optional: true
```

---

## 🛠️ Rutas Disponibles

| Método | Endpoint | Acción | Descripción |
|--------|----------|--------|-------------|
| GET | `/admin/categories` | `index` | Lista categorías |
| GET | `/admin/categories/new` | `new` | Formulario nueva |
| POST | `/admin/categories` | `create` | Crear categoría |
| GET | `/admin/categories/:id` | `show` | Ver categoría |
| GET | `/admin/categories/:id/edit` | `edit` | Formulario editar |
| PATCH | `/admin/categories/:id` | `update` | Actualizar |
| DELETE | `/admin/categories/:id` | `destroy` | Eliminar |

---

## 💡 Uso en el sistema

### Selección en Producto

Al crear/editar un producto:

```erb
<%= f.collection_select :category_id,
      Category.available, :id, :name,
      { prompt: "Selecciona una categoría" },
      { class: "form-select" } %>
```

### Contar productos por categoría

```ruby
category.products.count
category.products.low_stock.each(&:name)  # Productos con bajo stock
```

---

## 🧪 Tests

```ruby
# spec/models/category_spec.rb
describe Category do
  it 'is valid with valid attributes' do
    category = build(:category, name: 'Beverages', code: 'beverages')
    expect(category).to be_valid
  end

  it 'is invalid without a name' do
    category = build(:category, name: nil)
    expect(category).to be_invalid
  end

  describe 'uniqueness of code' do
    before { create(:category, code: 'beverages') }
    it { should validate_uniqueness_of(:code) }
  end
end
```