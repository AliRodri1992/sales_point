# Productos

Gestión del catálogo de productos en NEXO POS.

---

## 📦 Modelo Product

**Ubicación:** `app/models/product.rb`

### Atributos

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `code` | string | ✅ | Código único del producto |
| `name` | string | ✅ | Nombre del producto |
| `description` | text | ❌ | Descripción del producto |
| `price` | decimal | ✅ | Precio de venta |
| `cost` | decimal | ❌ | Costo de compra |
| `stock` | decimal | ✅ | Existencias actuales |
| `min_stock` | decimal | ❌ | Stock mínimo para alertas |
| `max_stock` | decimal | ❌ | Stock máximo permitido |
| `sku` | string | ❌ | SKU del producto |
| `barcode` | string | ❌ | Código de barras |
| `category_id` | bigint | ❌ | Categoría asociada |
| `sat_tax_id` | bigint | ❌ | Impuesto SAT aplicado |
| `sat_unit_key_id` | bigint | ❌ | Unidad SAT del producto |
| `status` | string | ✅ | Estado: active/inactive |
| `featured` | boolean | ✅ | ¿Producto destacado? |
| `position` | integer | ✅ | Posición en catálogo |
| `slug` | string | ❌ | URL amigable |
| `view_count` | integer | ✅ | Contador de vistas |
| `image_url` | string | ❌ | URL de imagen |
| `deleted_at` | datetime | ❌ | Soft delete |

---

## 🛠️ Validaciones

```ruby
# Código
validates :code, presence: true,
                 uniqueness: { case_sensitive: false },
                 length: { maximum: 50 },
                 format: { with: /\A[A-Za-z0-9\-_]+\z/ }

# Nombre
validates :name, presence: true, length: { maximum: 100 }

# Precio
validates :price, presence: true,
                  numericality: { greater_than_or_equal_to: 0 }

# Stock
validates :stock, presence: true,
                  numericality: { greater_than_or_equal_to: 0 }
```

---

## 🔗 Asociaciones

```ruby
belongs_to :category, optional: true
belongs_to :sat_unit_key, optional: true
belongs_to :sat_tax, optional: true
has_one_attached :image
```

---

## 🔍 Scopes

| Scope | Descripción | Ejemplo |
|-------|-------------|---------|
| `not_deleted` | Solo productos no eliminados | `Product.not_deleted` |
| `available` | Solo productos activos | `Product.available` |
| `with_category` | Incluir categoría | `Product.with_category` |
| `featured` | Solo productos destacados | `Product.featured` |
| `by_slug(slug)` | Buscar por slug | `Product.by_slug('producto-1')` |
| `sorted_by_position` | Ordenar por posición | `Product.sorted_by_position` |

---

## 📊 Métodos Útiles

### `low_stock?`

Verifica si el producto está por debajo del stock mínimo.

```ruby
def low_stock?
  return false if min_stock.nil? || min_stock.zero?
  stock <= min_stock
end
```

### `increment_view_count!`

Incrementa el contador de vistas (salta validaciones).

```ruby
def increment_view_count!
  increment!(:view_count)
end
```

### `to_param`

Devuelve el slug para URLs amigables.

```ruby
def to_param
  slug.presence
end
```

---

## 🔄 Flow de Creación/Edición

### Crear Producto

1. Acceder a `/admin/products/new`
2. Completar formulario con código, nombre y precio
3. Guardar producto
4. Recibir notificación SweetAlert2
5. Catálogo se actualiza en tiempo real vía Turbo Streams

### Editar Producto

1. Acceder a `/admin/products/:id/edit`
2. Modificar campos necesarios
3. Guardar cambios
4. Notificación y actualización en tiempo real

### Eliminar Producto

1. Acceder a `/admin/products/:id`
2. Hacer clic en "Eliminar"
3. Confirmar eliminación (SweetAlert2)
4. Soft delete (deleted_at se establece)
5. Producto desaparece de la lista

---

## 🎯 Búsqueda y Filtrado

### Parámetros de Búsqueda

```ruby
# Búsqueda por texto
GET /admin/products?search=coca

# Filtro por estado
GET /admin/products?status=active
GET /admin/products?status=inactive

# Filtro por destacado
GET /admin/products?featured=true
GET /admin/products?featured=false

# Ordenar por columna
GET /admin/products?sort=price&direction=asc
GET /admin/products?sort=price&direction=desc

# Paginación
GET /admin/products?page=2&per_page=20
```

### Implementación del Filtro

```ruby
# app/controllers/admin/products_controller.rb
def filter_scope(scope)
  scope = apply_search_filter(scope)
  scope = apply_featured_filter(scope)
  apply_status_filter(scope)
end

def apply_search_filter(scope)
  return scope if params[:search].blank?

  scope.where(
    'name ILIKE :q OR code ILIKE :q OR sku ILIKE :q OR barcode ILIKE :q',
    q: "%#{params[:search]}%"
  )
end
```

---

## 🔴 Low Stock Alerts

Los productos con stock por debajo del mínimo se marcan para alertas.

```ruby
# Uso en vistas
<% if product.low_stock? %>
  <span class="text-rose-600">Bajo stock</span>
<% end %>
```

---

## 📈 Calculos Deuda

```ruby
# Utilidad bruta
def gross_margin
  return 0 if price.zero?
  ((price - cost) / price * 100).round(2)
end

# Valor total en inventario
def total_value
  price * stock
end
```

---

## 🔄 Broadcast Updates

Los cambios en productos actualizan la lista en tiempo real:

```ruby
def broadcast_products_update
  html = render_to_string(
    partial: 'admin/products/list',
    formats: [:html],
    locals: { products: @products, total_count: @total_count, total_pages: @total_pages }
  )
  Turbo::StreamsChannel.broadcast_update_to(
    'products_catalog',
    target: 'admin_products_list',
    html: html
  )
end
```

---

## 🧪 Tests

```ruby
# spec/models/product_spec.rb
describe Product do
  describe 'validations' do
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:name) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
  end

  describe '#low_stock?' do
    it 'returns false without min_stock' do
      product = build(:product, min_stock: nil)
      expect(product.low_stock?).to be false
    end

    it 'returns true when stock is low' do
      product = build(:product, stock: 5, min_stock: 10)
      expect(product.low_stock?).to be true
    end
  end
end
```