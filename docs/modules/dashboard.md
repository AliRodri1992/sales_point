# Dashboard

Panel de administración y personalización en NEXO POS.

---

## 📊 Controlador Dashboard

**Ubicación:** `app/controllers/admin/dashboard_controller.rb`

### Acciones

| Acción | Ruta | Descripción |
|--------|------|-------------|
| `index` | `GET /admin/dashboard` | Dashboard principal |
| `save_preferences` | `POST /admin/dashboard/preferences` | Guardar preferencias |

---

## 🎨 Widgets del Dashboard

### KPI Cards

| Widget | Propósito | Métrica |
|--------|-----------|---------|
| `sales_today` | Ventas del día | Total en MXN |
| `transactions` | Transacciones | Contador |
| `average_ticket` | Ticket promedio | Total / Transacciones |
| `current_cash` | Efectivo actual | Caja abierta |

### Gráficos

- **Sales Chart**: Ventas con Chart.js / ApexCharts

### Acciones Rápidas

- Nueva venta
- Abrir POS
- Agregar producto
- Nuevo cliente

---

## 📐 GridStack Configuration

Widgets usan **GridStack.js** para arrastrar y soltar.

```javascript
// app/javascript/admin/dashboard.js
const grid = GridStack.init({
  float: true,
  cellSize: 40,
  removeTimeout: 0,
  disableOneColumnMode: 'all'
});
```

---

## 💾 Persistencia de Preferencias

### Modelo: DashboardPreference

**Ubicación:** `app/models/dashboard_preference.rb`

```ruby
create_table "dashboard_preferences", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.string "widget_id", null: false
  t.string "grid_type", null: false
  t.integer "position_x", default: 0, null: false
  t.integer "position_y", default: 0, null: false
  t.integer "width", default: 1, null: false
  t.integer "height", default: 1, null: false
  t.datetime "created_at", null: false
  t.datetime "deleted_at"
end
```

### API de Guardado

```ruby
# POST /admin/dashboard/preferences
def save_preferences
  DashboardPreference.transaction do
    dashboard_preferences_params.each do |widget|
      save_widget_preference(widget)
    end
  end
  render json: { success: true }
end
```

**Parámetros:**
```json
{
  "widgets": [
    {
      "grid_type": "weekly",
      "widget_id": "sales",
      "x": 0,
      "y": 0,
      "w": 4,
      "h": 3
    }
  ]
}
```

---

## 🎯 Layout del Dashboard

```erb
<!-- app/views/admin/dashboard/index.html.erb -->
<div class="space-y-6">
  <div class="grid grid-cols-1 gap-6 lg:grid-cols-2 xl:grid-cols-4">
    <!-- KPI Cards -->
    <%= render Admin::KpiCardComponent.new(...) %>
  </div>
  
  <!-- Charts -->
  <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
    <%= render Admin::SalesChartComponent.new(...) %>
    <%= render Admin::LowStockComponent.new(...) %>
  </div>
</div>
```

---

## 🔄 Estado del Sidebar

El sidebar tiene un estado colapsado que se guarda en la cookie del usuario.

```ruby
# En ApplicationController
after_action :set_action_cable_user_id_cookie

# En User model
def sidebar_collapsed?
  sidebar_collapsed
end
```

---

## 🎨 Clases CSS del Dashboard

```html
<!-- Layout principal -->
<div class="flex min-h-screen">
  <!-- Sidebar (colapsable) -->
  <aside class="flex w-64 shrink-0 flex-col">
    <!-- Contenido -->
  </aside>
  
  <!-- Main Content -->
  <div class="flex min-w-0 flex-1 flex-col">
    <!-- Topbar -->
    <!-- Breadcrumbs -->
    <main class="flex-1 px-4 py-6 lg:px-6">
      <%= yield %>
    </main>
    <!-- Footer -->
  </div>
</div>
```

---

## 🧪 Tests

```ruby
# spec/models/dashboard_preference_spec.rb
describe DashboardPreference do
  it { should belong_to(:user) }
  
  it 'is valid with valid attributes' do
    pref = build(:dashboard_preference,
                 user: create(:user),
                 widget_id: 'sales',
                 grid_type: 'weekly')
    expect(pref).to be_valid
  end
end

# spec/requests/admin/dashboard_spec.rb
describe 'Admin::Dashboard' do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET #index' do
    it 'returns 200 OK' do
      get admin_dashboard_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #save_preferences' do
    let(:widgets) do
      [{ grid_type: 'weekly', widget_id: 'sales', x: 0, y: 0, w: 4, h: 3 }]
    end

    it 'saves widget preferences' do
      post save_preferences_path, params: { widgets: widgets }
      expect(response).to have_http_status(:ok)
    end
  end
end
```