# Comunicaciones

Sistema de chat y conversaciones en NEXO POS.

---

## 💬 Modelos

### Conversation

**Ubicación:** `app/models/conversation.rb`

```ruby
class Conversation < ApplicationRecord
  enum :conversation_type, { direct: 'direct' }, default: 'direct'
  
  has_many :conversation_participants, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :users, through: :conversation_participants
end
```

### Message

**Ubicación:** `app/models/message.rb`

```ruby
class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  
  validates :body, presence: true
end
```

### ConversationParticipant

**Ubicación:** `app/models/conversation_participant.rb`

```ruby
class ConversationParticipant < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  
  validates :user_id, uniqueness: {
    scope: %i[conversation_id],
    conditions: -> { where(deleted_at: nil) }
  }
end
```

---

## 🛠️ Rutas de API

| Método | Endpoint | Acción | Descripción |
|--------|----------|--------|-------------|
| GET | `/conversations/:id` | `show` | Ver conversación |
| POST | `/conversations` | `create` | Crear conversación |
| POST | `/conversations/:id/messages` | `create` | Enviar mensaje |

---

## 📡 WebSocket (ActionCable)

### Conexión

**Archivo:** `app/channels/application_cable/connection.rb`

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      user_id = cookies.signed[:user_id]
      return unless user_id
      User.find_by(id: user_id) || reject_unauthorized_connection
    end
  end
end
```

---

## 🎮 Stimulus Controllers

### conversation_form_controller.js

**Elemento:** `data-controller="conversation-form"`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    event.preventDefault()
    // Enviar mensaje vía AJAX
  }
}
```

### conversation_messages_controller.js

**Elemento:** `data-controller="conversation-messages"`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
```

---

## 🖼️ Vistas del Chat

```erb
<!-- app/views/conversations/show.html.erb -->
<div class="conversation-messages" data-controller="conversation-messages">
  <%= render @messages %>
</div>

<%= form_with model: [ @conversation, @message ],
      data: { controller: "conversation-form" },
      local: true do |f| %>
  <%= f.text_area :body, placeholder: "Escribe un mensaje..." %>
  <%= f.submit "Enviar" %>
<% end %>
```

---

## 📋 Componentes UI

### Chat Component

**Archivo:** `app/components/admin/chat_component.rb`

```ruby
module Admin
  class ChatComponent < ViewComponent::Base
    def initialize(title: "Chat")
      @title = title
    end
  end
end
```

---

## 🎨 Estilos del Chat

```html
<!-- Mensajes -->
<div class="message border-b border-slate-100 p-4">
  <div class="text-xs text-slate-500">
    <%= message.user.display_name %>
  </div>
  <div class="mt-1 text-slate-800">
    <%= message.body %>
  </div>
</div>

<!-- Contenedor -->
<div class="flex-1 overflow-y-auto p-4">
  <%= render @messages %>
</div>
```

---

## 🧪 Tests

```ruby
# spec/models/message_spec.rb
describe Message do
  it { should belong_to(:conversation) }
  it { should belong_to(:user) }
  it { should validate_presence_of(:body) }
end

# spec/models/conversation_spec.rb
describe Conversation do
  it { should have_many(:messages).dependent(:destroy) }
  it { should have_many(:users).through(:conversation_participants) }
end
```