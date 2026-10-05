# Estructura del Proyecto

Documentación detallada de la estructura de carpetas y archivos de NEXO POS.

---

## 📁 Estructura Principal

```text
sale_point/
├── .ruby-version              # Versión Ruby (3.3.6)
├── Gemfile                    # Dependencias Ruby
├── Gemfile.lock               # Lock de dependencias
├── Rakefile                   # Tasks de Rake
├── bin/                       # Binarios de ejecución
│   ├── dev                    # Servidor de desarrollo
│   ├── rails                  # CLI de Rails
│   ├── setup                  # Setup inicial
│   └── spring                 # Spring application preloader
├── config/                    # Configuración de Rails
├── db/                        # Base de datos
├── docs/                      # [NUEVO] Documentación técnica
├── public/                    # Recursos públicos
├── spec/                      # Tests RSpec
├── app/                       # Código de la aplicación
└── test/                      # Test unitario (si existe)
```

---

## 📂 Estructura de `app/`

### Controllers

```text
app/controllers/
├── application_controller.rb     # Base con set_locale, current_language
├── admin/
│   ├── dashboard_controller.rb   # Dashboard del admin
│   ├── sidebar_controller.rb     # Estado del sidebar
│   ├── products_controller.rb    # CRUD productos
│   ├── categories_controller.rb  # CRUD categorías
│   └── languages_controller.rb   # CRUD idiomas
├── users/
│   ├── registrations_controller.rb
│   ├── sessions_controller.rb
│   ├── passwords_controller.rb
│   ├── unlocks_controller.rb
│   ├── confirmations_controller.rb
│   └── omniauth_callbacks_controller.rb
├── home_controller.rb            # Página principal
├── dashboard_controller.rb       # Dashboard público
├── system_roles_controller.rb    # CRUD roles
├── messages_controller.rb        # API mensajes
├── conversations_controller.rb   # API conversaciones
├── notifications_controller.rb   # Notificaciones
└── demo_requests_controller.rb   # Solicitud demo
```

### Models

```text
app/models/
├── application_record.rb         # Base de modelos
├── concerns/                     # Concerns compartidos
│   └── .keep
├── user.rb                       # Usuario con Devise
├── product.rb                    # Productos
├── category.rb                   # Categorías
├── language.rb                   # Idiomas
├── branch.rb                     # Sucursales
├── system_role.rb                # Roles del sistema
├── user_role.rb                  # Asociación User-Role
├── dashboard_preference.rb       # Preferencias dashboard
├── address.rb                    # Direcciones
├── conversation.rb               # Conversaciones
├── conversation_participant.rb   # Participantes conversación
├── message.rb                    # Mensajes
├── demo_request.rb               # Solicitud demo
├── theme.rb                      # Temas UI
├── sat_tax.rb                    # Impuestos SAT
├── sat_unit_key.rb               # Unidades SAT
├── sat_bank.rb                   # Bancos SAT
├── sat_currency.rb               # Monedas SAT
├── sat_fiscal_regime.rb          # Regímenes fiscales
├── sat_payment_method.rb         # Métodos de pago SAT
├── sat_payment_method_type.rb    # Tipos de pago SAT
├── sat_month.rb                  # Meses SAT
├── membership_plan.rb            # Planes de membresía
├── membership_feature.rb         # Características membresía
└── membership_plan_feature.rb    # Relación planes-características
```

### Views

```text
app/views/
├── layouts/
│   ├── application.html.erb      # Layout principal
│   ├── admin_dashboard.html.erb  # Layout admin
│   ├── authentication.html.erb   # Layout login
│   └── mailer.html.erb           # Layout correos
├── admin/
│   ├── products/
│   │   ├── index.html.erb        # Lista productos
│   │   ├── show.html.erb         # Ver producto
│   │   ├── new.html.erb          # Formulario nuevo
│   │   ├── edit.html.erb         # Formulario editar
│   │   ├── _form.html.erb        # Parcial formulario
│   │   ├── _list.html.erb        # Lista paginated
│   │   └── _panel.html.erb       # Panel lateral
│   ├── categories/
│   │   ├── index.html.erb
│   │   ├── show.html.erb
│   │   ├── new.html.erb
│   │   ├── edit.html.erb
│   │   └── _panel.html.erb
│   ├── languages/
│   │   ├── index.html.erb
│   │   └── _panel.html.erb
│   ├── shared/
│   │   ├── _sidebar.html.erb
│   │   ├── _topbar.html.erb
│   │   ├── _breadcrumbs.html.erb
│   │   ├── _flash.html.erb
│   │   ├── _notifications*.erb*
│   │   └── *_language_selector*.erb*
│   └── dashboard/
│       └── index.html.erb        # Dashboard con widgets
├── devise/
│   ├── sessions/
│   │   └── new.html.erb          # Login
│   └── registrations/
│       └── new.html.erb          # Registro
├── home/
│   └── index.html.erb            # Página principal
└── demo_request_mailer/
    └── new_request.html.erb
```

### Components (ViewComponent)

```text
app/components/
├── admin/
│   ├── kpi_card_component.rb
│   ├── low_stock_component.rb
│   ├── quick_actions_component.rb
│   ├── recent_sales_component.rb
│   └── sales_chart_component.rb
├── landing/
│   ├── faq_component.rb
│   ├── screenshot_component.rb
│   ├── footer_component.rb
│   ├── features_component.rb
│   ├── navbar_component.rb
│   ├── testimonial_component.rb
│   ├── pricing_card_component.rb
│   ├── modules_component.rb
│   ├── feature_card_component.rb
│   ├── cta_component.rb
│   └── hero_component.rb
└── ui/
    ├── icon_component.rb
    ├── statistic_component.rb
    ├── card_component.rb
    ├── icon_box_component.rb
    ├── badge_component.rb
    └── button_component.rb
```

---

## 📦 Configuración por Directorio

### `config/`

```text
config/
├── application.rb              # Config base de Rails
├── boot.rb                     # Boot inicial
├── credentials.yml.enc         # Credenciales encriptadas
├── master.key                  # Key para descifrar
├── database.yml                # Config DB
├── cable.yml                   # ActionCable
├── cache.yml                   # Caching
├── queue.yml                   # Solid Queue
├── puma.rb                    # Servidor Puma
├── sidekiq.yml                # Sidekiq config
├── deploy.yml                 # Kamal deploy
├── recurring.yml              # Solid Queue recurring
│
├── environments/                # Config por ambiente
│   ├── development.rb
│   ├── test.rb
│   ├── production.rb
│   └── staging.rb
│
├── initializers/                # Inicializadores
│   ├── application.rb
│   ├── assets.rb
│   ├── backtrace_printer.rb
│   ├── bootstrap.rb
│   ├── content_security_policy.rb
│   ├── cssbundling.rb
│   ├── database.rb
│   ├── devise.rb
│   ├── devise_security.rb
│   ├── filter_parameter_logging.rb
│   ├── i18n_database_backend.rb
│   ├── inflections.rb
│   ├── jetbrains.rb
│   ├── kredis.rb
│   ├── mime_types.rb
│   ├── notifed.rb
│   ├── patched_activerecord_result.rb
│   ├── rack_attack.rb
│   ├── rails_icons.rb
│   ├── secure_headers.rb
│   ├── session_store.rb
│   └── suitcase.rb
│
├── locales/                    # Archivos de traducción
│   ├── en.yml
│   ├── es.yml
│   └── ko.yml
│
└── routes.rb                   # Definición de rutas
```

### `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Rutas públicas
  root 'home#index'
  get '/home/index', to: 'home#index'
  get '/dashboard/index', to: 'dashboard#index'
  patch '/language', to: 'languages#update'
  
  # Autenticación Devise
  devise_for :users, controllers: { ... }
  
  # Admin namespace
  namespace :admin do
    resources :products
    resources :categories
    resources :languages
    get '/dashboard', to: 'dashboard#index'
    post 'dashboard/preferences', to: 'dashboard#save_preferences'
  end
  
  # Recursos del sistema
  resources :system_roles
  resources :demo_requests, only: %i[new create]
  
  # Notificaciones
  resources :notifications, only: [] do
    collection { post :mark_all_read }
  end
  
  # Conversaciones
  resources :conversations, only: %i[show create] do
    resources :messages, only: %i[create]
  end
end
```

---

## 🧪 Estructura de Tests

```text
spec/
├── rails_helper.rb              # Config base RSpec
├── spec_helper.rb               # Config global
├── support/
│   ├── factory_bot.rb
│   ├── shoulda_matchers.rb
│   ├── database_cleaner.rb
│   ├── capybara.rb
│   └── view_component.rb
│
├── models/                      # Tests de modelo
│   ├── product_spec.rb
│   ├── category_spec.rb
│   ├── language_spec.rb
│   ├── user_spec.rb
│   ├── system_role_spec.rb
│   └── ...
│
├── requests/                    # Tests de request
│   └── admin/
│       ├── products_spec.rb
│       ├── categories_spec.rb
│       └── languages_spec.rb
│
├── controllers/               # (si existen)
│
├── helpers/                     # Tests de helpers
│   └── application_helper_spec.rb
│
├── components/                  # Tests de ViewComponents
│   └── admin/
│       ├── kpi_card_component_spec.rb
│       ├── low_stock_component_spec.rb
│       └── ...
│
├── features/                    # Tests de features
│   └── system_roles_spec.rb
│
├── views/                       # Tests de vistas
│   ├── home/
│   │   └── index.html.erb_spec.rb
│   └── dashboard/
│       └── index.html.erb_spec.rb
│
└── factories/                   # FactoryBot
    ├── products.rb
    ├── categories.rb
    ├── languages.rb
    ├── users.rb
    ├── system_roles.rb
    ├── sat_taxes.rb
    └── ...
```

---

## 📦 Assets

### JavaScript

```text
app/javascript/
├── application.js              # Entry point
├── admin/
│   └── dashboard.js            # Dashboard admin
└── controllers/
    ├── application.js
    ├── index.js                # Stimulus manifest
    ├── products_controller.js
    ├── products_search_controller.js
    ├── categories_controller.js
    ├── categories_search_controller.js
    ├── languages_controller.js
    ├── language_selector_controller.js
    ├── dashboard_controller.js (GridStack)
    ├── modal_controller.js
    ├── swal_confirm_controller.js
    ├── swal_flash_controller.js
    ├── navbar_controller.js
    ├── clock_controller.js
    ├── online_users_controller.js
    ├── conversation_form_controller.js
    ├── conversation_messages_controller.js
    ├── terminal_controller.js
    └── hello_controller.js       # Ejemplo scaffold
```

### CSS

```text
app/assets/stylesheets/
├── application.css
├── application.tailwind.css    # Tailwind principal
├── admin_dashboard.css
├── fonts.css
└── components/
    ├── _buttons.css
    └── _forms.css
```

### Builds

```text
app/assets/builds/
├── application.css             # CSS compilado
├── application.js              # JS compilado
└── (*.css, *.js maps)          # Source maps
```

---

## 📚 Documentación de Archivos Clave

### `Gemfile`

```ruby
# Gems principales
gem 'rails', '~> 8.1.3'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'

# Autenticación
gem 'devise'
gem 'devise-security'

# Frontend
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'cssbundling-rails'
gem 'jsbundling-rails'

# Background Jobs
gem 'sidekiq'
gem 'solid_queue'
gem 'solid_cable'

# Notificaciones
gem 'noticed'

# Soft Delete
gem 'paranoia'

# Auditoría
gem 'paper_trail'

# Seguridad
gem 'rack-attack'

# i18n database backend
gem 'i18n'
gem 'i18n-tasks'

# Desarrollo/Test
group :development, :test do
  gem 'rspec-rails'
  gem 'rubocop'
  gem 'pry-rails'
  gem 'web-console'
  # ...
end
```

---

## 🔧 Comandos Útiles

### Rails

```bash
# Navegar entre entornos
bin/rails console               # Consola interactiva
bin/rails server                # Servidor
bin/rails generate controller   # Generar controlador
bin/rails generate model        # Generar modelo
bin/rails db:migrate            # Ejecutar migraciones
bin/rails routes                  # Ver rutas
```

### RSpec

```bash
bundle exec rspec                 # Ejecutar todos los tests
bundle exec rspec spec/models     # Solo tests de modelo
bundle exec rspec spec/requests   # Solo tests de request
bundle exec rspec --format doc    # Output detallado
```

### Rubocop

```bash
bundle exec rubocop               # Ver offenses
bundle exec rubocop -a            # Auto-corregir
```

---

## 🗺️ Mapa de Archivos Importantes

| Propósito | Archivo |
|-----------|---------|
| Config base | `config/application.rb` |
| Routing | `config/routes.rb` |
| Modelo User | `app/models/user.rb` |
| Controlador Products | `app/controllers/admin/products_controller.rb` |
| Vistas admin | `app/views/admin/**/*.html.erb` |
| Layouts | `app/views/layouts/*.html.erb` |
| Stimulus | `app/javascript/controllers/index.js` |
| Tailwind | `app/assets/stylesheets/application.tailwind.css` |
| Tests | `spec/**/*_spec.rb` |
| Factories | `spec/factories/*.rb` |