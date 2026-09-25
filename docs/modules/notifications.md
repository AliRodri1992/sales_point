# Notificaciones

Sistema de notificaciones en tiempo real en NEXO POS.

---

## 📧 Notificaciones con Noticed

**Gem:** `noticed`

### Modelo Base

```ruby
# Las notificaciones usan el modelo base de Noticed
class ProductNotification < Noticed::Event
  required_param :action
  required_param :user

  delegate :name, :code, to: :record

  def message
    t("admin.shared.notifications.product.#{action}", name: record.name)
  end
end
```

---

## 📋 Tipos de Notificaciones

### ProductNotification

**Archivo:** `app/notifications/product_notification.rb`

**Triggers:**
- Creación de producto
- Actualización de producto
- Eliminación de producto (soft delete)

**Campos:**
```ruby
params[:action]  # created, updated, destroyed
params[:user]    # Usuario que realizó la acción
params[:record]  # Producto afectado
```

### CategoryNotification

**Archivo:** `app/notifications/category_notification.rb`

**Triggers:**
- Creación de categoría
- Actualización de categoría
- Eliminación de categoría

### LanguageNotification

**Archivo:** `app/notifications/language_notification.rb`

**Triggers:**
- Creación de idioma
- Actualización de idioma
- Eliminación de idioma

---

## 📡 Entrega de Notificaciones

### Entrega Inmediata

```ruby
def notify_product(user, product, action)
  ProductNotification
    .with(action: action, record: product, user: user)
    .deliver(user, enqueue_job: false)
end
```

### Broadcast en Tiempo Real

```ruby
def user.broadcast_notifications_refresh
  Turbo::StreamsChannel.broadcast_replace_to(
    "notifications_#{id}",
    target: 'notifications_badge',
    partial: 'admin/shared/notifications_badge',
    locals: { user: self }
  )
end
```

---

## ✉️ Tabla de Notificaciones

### noticed_events

```ruby
create_table "noticed_events", force: :cascade do |t|
  t.datetime "created_at", null: false
  t.integer "notifications_count"
  t.jsonb "params"
  t.bigint "record_id"
  t.string "record_type"
  t.string "type"
  t.datetime "updated_at", null: false
end
```

### noticed_notifications

```ruby
create_table "noticed_notifications", force: :cascade do |t|
  t.datetime "created_at", null: false
  t.bigint "event_id", null: false
  t.datetime "read_at"
  t.datetime "seen_at"
  t.bigint "recipient_id", null: false
  t.string "recipient_type", null: false
  t.string "type"
  t.datetime "updated_at", null: false
end
```

---

## 🎨 Vistas de Notificaciones

### Badge (Dropdown Header)

**Archivo:** `app/views/admin/shared/_notifications_badge.html.erb`

```erb
<button data-controller="turbo-stream"
        data-turbo-stream-action="replace"
        data-turbo-stream-target="notifications-badge"
        href="#"
        class="relative inline-flex items-center justify-center rounded-lg text-slate-500 hover:bg-slate-100 hover:text-slate-900">
  <%= icon("bell", class: "size-5") %>
  <% if user.unread_notifications.exists? %>
    <span class="absolute -top-1 -right-1 inline-flex h-5 w-5 items-center justify-center rounded-full bg-rose-500 text-xs font-medium text-white">
      <%= user.unread_notifications.count %>
    </span>
  <% end %>
</button>
```

### Lista de Notificaciones

**Archivo:** `app/views/admin/shared/_notifications_list.html.erb`

```erb
<div class="max-w-md space-y-4">
  <% user.notifications.each do |notification| %>
    <%= render "notification", notification: notification %>
  <% end %>
</div>
```

---

## 🔔 Componentes Stimulus

### Notifications Controller

**Archivo:** `app/javascript/controllers/notifications_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  markAllRead() {
    fetch("/notifications/mark_all_read", {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector("[csrf-token]").dataset.csrfToken }
    }).then(() => {
      this.element.querySelectorAll(".notification-badge").forEach(el => {
        el.style.display = "none"
      })
    })
  }
}
```

---

## 🛠️ API Endpoints

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/notifications/mark_all_read` | Marcar todas como leídas |
| GET | `/notifications` | (No implementado) Ver notificaciones |

---

## 📊 Tipos de Notificaciones en UI

```erb
<!-- app/views/admin/shared/_notifications.html.erb -->
<span class="sr-only">New notifications</span>
<%= icon("bell", class: "size-5") %>

<span class="absolute -top-1 -right-1 inline-flex h-5 w-5 items-center justify-center rounded-full bg-rose-500 text-xs font-medium text-white">
  <%= user.unread_notifications.count %>
</span>

<div class="absolute right-0 mt-2 w-80 rounded-xl border border-slate-200 bg-white shadow-xl">
  <div class="border-b border-slate-100 px-4 py-3">
    <p class="font-semibold">Notificaciones</p>
    <p class="text-xs text-slate-500">Tienes <%= user.unread_notifications.count %> sin leer</p>
  </div>
  
  <div class="max-h-96 overflow-y-auto">
    <%= render user.recent_notifications(limit: 10) %>
  </div>
</div>
```

---

## 📋 Tipos de Notificaciones (en archivos de traducción)

```yaml
# config/locales/es.yml
admin:
  shared:
    notifications:
      types:
        chat: "Chat"
        demo_request: "Solicitud de demo"
        language: "Idioma"
        category: "Categoría"
        product: "Producto"
      language:
        created: "Se creó el idioma '%{name}'"
        updated: "Se actualizó el idioma '%{name}'"
        destroyed: "Se eliminó el idioma '%{name}'"
      category:
        created: "Se creó la category '%{name}'"
        updated: "Se actualizó la category '%{name}'"
        destroyed: "Se eliminó la category '%{name}'"
      product:
        created: "Se creó el producto '%{name}'"
        updated: "Se actualizó el producto '%{name}'"
        destroyed: "Se eliminó el producto '%{name}'"
```

---

## 🧪 Tests

```ruby
# spec/models/product_notification_spec.rb
describe ProductNotification do
  let(:user) { create(:user) }
  let(:product) { create(:product, name: 'Test Product') }

  it 'creates notification with correct message' do
    notification = ProductNotification
      .with(action: 'created', record: product, user: user)
      .deliver_later
    
    expect(notification.message).to include('Test Product')
  end
end
```