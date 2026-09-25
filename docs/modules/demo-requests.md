# Solicitudes de Demo

Sistema de captura de leads para demostraciones de NEXO POS.

---

## 📝 Modelo DemoRequest

**Ubicación:** `app/models/demo_request.rb`

### Atributos

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `name` | string | ✅ | Nombre del solicitante |
| `email` | string | ✅ | Email corporativo |
| `company` | string | ❌ | Nombre de la empresa |
| `phone` | string | ❌ | Teléfono de contacto |
| `message` | text | ❌ | Mensaje adicional |
| `status` | string | ✅ | Estado: pending/approved/rejected |
| `deleted_at` | datetime | ❌ | Soft delete |

### Estado por Defecto

```ruby
enum :status, { pending: 'pending', approved: 'approved', rejected: 'rejected' }, default: 'pending'
```

---

## 🎨 Validaciones

```ruby
validates :name, presence: true
validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :status, presence: true
```

---

## 🛠️ Rutas

| Método | Endpoint | Acción | Descripción |
|--------|----------|--------|-------------|
| GET | `/demo_requests/new` | `new` | Formulario de solicitud |
| POST | `/demo_requests` | `create` | Enviar solicitud |

---

## 📧 Notificaciones

### DemoRequestNotification

**Archivo:** `app/notifications/demo_request_notification.rb`

```ruby
class DemoRequestNotification < Noticed::Event
  required_param :request
  
  delegate :name, :email, :company, to: :request
  
  def message
    t('admin.notifications.demo_request.created', 
      name: request.name, 
      company: request.company)
  end
end
```

---

## 🎭 Vistas

### Formulario de Solicitud

**Archivo:** `app/views/demo_requests/new.html.erb`

```erb
<div class="max-w-lg mx-auto">
  <h1>Solicitar Demo</h1>
  
  <%= form_with model: @demo_request, url: demo_requests_path do |f| %>
    <div>
      <%= f.label :name %>
      <%= f.text_field :name, required: true %>
    </div>
    
    <div>
      <%= f.label :email %>
      <%= f.email_field :email, required: true %>
    </div>
    
    <div>
      <%= f.label :company %>
      <%= f.text_field :company %>
    </div>
    
    <%= f.submit "Enviar Solicitud" %>
  <% end %>
</div>
```

---

## 📧 Mailer (Opcional)

### DemoRequestMailer

**Archivo:** `app/mailers/demo_request_mailer.rb`

```ruby
class DemoRequestMailer < ApplicationMailer
  def new_request(demo_request)
    @demo_request = demo_request
    mail(to: ENV['ADMIN_EMAIL'], subject: 'Nueva solicitud de demo')
  end
end
```

---

## 🎨 Componentes Stimulus

### Demo Request Form Controller

```javascript
// app/javascript/controllers/demo_request_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async submit(event) {
    event.preventDefault()
    
    const form = event.target
    const response = await fetch(form.action, {
      method: 'POST',
      body: new FormData(form),
      headers: {
        'X-CSRF-Token': document.querySelector('[csrf-token]').dataset.csrfToken
      }
    })
    
    if (response.ok) {
      this.showSuccess()
    }
  }
  
  showSuccess() {
    // Mostrar SweetAlert2
    Swal.fire({
      icon: 'success',
      title: '¡Solicitud enviada!',
      text: 'Nos pondremos en contacto pronto.'
    })
  }
}
```

---

## 📊 Estadísticas (No implementado)

Funcionalidad futura:
- Dashboard de leads
- Funnel de conversión
- Tracking de campañas

---

## 🧪 Tests

```ruby
# spec/models/demo_request_spec.rb
describe DemoRequest do
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:email) }
  
  describe 'email format validation' do
    it 'accepts valid emails' do
      request = build(:demo_request, email: 'test@example.com')
      expect(request).to be_valid
    end
    
    it 'rejects invalid emails' do
      request = build(:demo_request, email: 'invalid-email')
      expect(request).to be_invalid
    end
  end
end

# spec/requests/demo_requests_spec.rb
describe 'DemoRequests' do
  describe 'POST #create' do
    let(:valid_params) do
      {
        demo_request: {
          name: 'John Doe',
          email: 'john@example.com',
          company: 'Test Corp'
        }
      }
    end

    it 'creates a new demo request' do
      expect {
        post demo_requests_path, params: valid_params
      }.to change(DemoRequest, :count).by(1)
    end

    it 'redirects to home with notice' do
      post demo_requests_path, params: valid_params
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to be_present
    end
  end
end
```