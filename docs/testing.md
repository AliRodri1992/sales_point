# Testing

Documentación de la estrategia de testing en NEXO POS.

---

## 🧪 Stack de Testing

| Herramienta | Uso |
|-------------|-----|
| **RSpec** | Framework de testing |
| **FactoryBot** | Generación de datos de prueba |
| **Shoulda Matchers** | Matchers para validaciones y asociaciones |
| **Capybara** | Testing de integración |
| **DatabaseCleaner** | Limpieza de base de datos |
| **SimpleCov** | Cobertura de código |
| **Timecop** | Mocking de fechas |
| **Faker** | Generación de datos falsos |

---

## 📁 Estructura de Tests

```text
spec/
├── rails_helper.rb           # Configuración RSpec + Rails
├── spec_helper.rb            # Configuración base
│
├── support/                  # Helpers y configuraciones
│   ├── factory_bot.rb
│   ├── shoulda_matchers.rb
│   ├── database_cleaner.rb
│   ├── capybara.rb
│   └── view_component.rb
│
├── models/                   # Tests de modelos
│   ├── product_spec.rb
│   ├── category_spec.rb
│   ├── language_spec.rb
│   ├── user_spec.rb
│   ├── system_role_spec.rb
│   └── ...
│
├── requests/                 # Tests de peticiones HTTP
│   └── admin/
│       ├── products_spec.rb
│       ├── categories_spec.rb
│       └── languages_spec.rb
│
├── controllers/              # Tests de controladores
│
├── helpers/                  # Tests de helpers
│   └── application_helper_spec.rb
│
├── components/               # Tests de ViewComponents
│   └── admin/
│       ├── kpi_card_component_spec.rb
│       └── ...
│
├── views/                    # Tests de vistas
│
├── features/                 # Tests de features
│   └── system_roles_spec.rb
│
└── factories/                # Factories de FactoryBot
    ├── products.rb
    ├── categories.rb
    ├── languages.rb
    ├── users.rb
    └── ...
```

---

## 🔧 Configuración

### `rails_helper.rb`

```ruby
# spec/rails_helper.rb
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_group 'Models', 'app/models'
end

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rspec/rails'

# Requires supporting ruby files with custom matchers and macros, etc.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Warden::Test::Helpers
  
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

### Factories

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    user_type { 'employee' }
    status { 'active' }
    theme { 'theme-material-red' }
  end
end
```

---

## 📝 Ejemplos de Tests

### Modelo: Product

```ruby
# spec/models/product_spec.rb
require 'rails_helper'

RSpec.describe Product, type: :model do
  describe 'validaciones' do
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
  end

  describe 'asociaciones' do
    it { should belong_to(:category).optional }
    it { should belong_to(:sat_tax).optional }
  end

  describe 'scopes' do
    it 'returns non-deleted products' do
      expect(Product.not_deleted).to include(build(:product))
    end
  end

  describe '#low_stock?' do
    context 'when min_stock is nil or zero' do
      it 'returns false' do
        product = build(:product, min_stock: nil)
        expect(product.low_stock?).to be false
      end
    end
  end
end
```

### Request: ProductsController

```ruby
# spec/requests/admin/products_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::Products', type: :request do
  let(:user) { create(:user) }
  let!(:product) { create(:product, name: 'Test Product') }

  before { sign_in user }

  describe 'GET /admin/products' do
    it 'returns 200 OK' do
      get admin_products_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders index template' do
      get admin_products_path
      expect(response).to render_template(:index)
    end
  end

  describe 'POST /admin/products' do
    let(:valid_params) do
      {
        product: {
          code: 'PROD-001',
          name: 'New Product',
          price: 99.99,
          stock: 100
        }
      }
    end

    it 'creates a new product' do
      expect {
        post admin_products_path, params: valid_params
      }.to change(Product, :count).by(1)
    end

    it 'redirects to admin_products_path' do
      post admin_products_path, params: valid_params
      expect(response).to redirect_to(admin_products_path)
    end
  end
end
```

---

## 🎯 Ejecutar Tests

### Comandos Básicos

```bash
# Ejecutar todos los tests
bundle exec rspec

# Ejecutar con formato detallado
bundle exec rspec --format documentation

# Ejecutar tests específicos
bundle exec rspec spec/models/product_spec.rb
bundle exec rspec spec/requests/admin/products_spec.rb
bundle exec rspec spec/helpers/application_helper_spec.rb

# Ejecutar con filtro
bundle exec rspec -e "Product"  # Solo ejemplos con "Product" en el nombre
bundle exec rspec -t "fast"     # Solo tests marcados como slow

# Ver cobertura
bundle exec rspec
# SimpleCov genera coverage/ con reportes HTML
```

### Opciones Útiles

```bash
# Fail fast - detener al primer error
bundle exec rspec -f

# Format nested (salida bonita)
bundle exec rspec --format nested

# Documentar ejemplos fallidos
bundle exec rspec --format documentation

# Sólo errores
bundle exec rspec --example "error"
```

---

## 🧪 Pruebas de Modelo: User

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'Devise modules' do
    it { should have_db_column(:email).of_type(:string) }
    it { should have_db_column(:encrypted_password).of_type(:string) }
  end

  describe 'validaciones' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_inclusion_of(:user_type).in_array(%w[employee customer supplier]) }
    it { should validate_inclusion_of(:status).in_array(%w[active suspended blocked deleted]) }
  end

  describe '#admin?' do
    it 'returns true for super_admin' do
      user = create(:user)
      create(:system_role, :super_admin, users: [user])
      expect(user.admin?).to be true
    end

    it 'returns false for regular employee' do
      user = create(:user, :employee)
      expect(user.admin?).to be false
    end
  end

  describe '#role?' do
    let(:user) { create(:user) }
    let(:admin_role) { create(:system_role, code: 'administrator') }

    before { user.user_roles.create!(system_role: admin_role) }

    it 'returns true when user has the role' do
      expect(user.role?('administrator')).to be true
    end

    it 'returns false when user does not have the role' do
      expect(user.role?('super_admin')).to be false
    end
  end
end
```

---

## 🧪 Pruebas de Request: Products

```ruby
# spec/requests/admin/products_spec.rb
require 'rails_helper'

RSpec.describe 'Products API', type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before { sign_in admin_user }

  describe 'GET #index' do
    let!(:products) { create_list(:product, 5) }

    it 'returns all products' do
      get admin_products_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(products.first.name)
    end

    context 'with search' do
      before { create(:product, name: 'Special Item') }

      it 'filters by search term' do
        get admin_products_path, params: { search: 'Special' }
        expect(response.body).to include('Special Item')
      end
    end

    context 'with status filter' do
      before do
        create(:product, status: 'active')
        create(:product, :inactive)
      end

      it 'filters by status' do
        get admin_products_path, params: { status: 'active' }
        expect(response.body).to include('active')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      { product: attributes_for(:product) }
    end

    it 'creates a new product' do
      expect {
        post admin_products_path, params: valid_attributes
      }.to change(Product, :count).by(1)
    end

    it 'broadcasts products update' do
      expect {
        post admin_products_path, params: valid_attributes
      }.to have_broadcasted_to('products_catalog')
    end
  end

  describe 'DELETE #destroy' do
    let!(:product) { create(:product) }

    it 'soft deletes the product' do
      expect {
        delete admin_product_path(product)
      }.to change { product.reload.deleted_at }.from(nil).to(be_present)
      expect(response).to redirect_to(admin_products_path)
    end
  end
end
```

---

## 🎨 ViewComponent Tests

```ruby
# spec/components/admin/kpi_card_component_spec.rb
RSpec.describe Admin::KpiCardComponent, type: :component do
  it 'renders correctly' do
    render { component }
    expect(rendered).to have_css('.kpi-card')
  end

  it 'displays the title' do
    render(:simple, title: 'Sales Today', value: '$1,234.56')
    expect(rendered).to have_content('Sales Today')
  end

  it 'displays the value' do
    render(:simple, title: 'Sales Today', value: '$1,234.56')
    expect(rendered).to have_content('$1,234.56')
  end
end
```

---

## 📊 Cobertura de Código

### SimpleCov Configuration

```ruby
# spec/rails_helper.rb (fragmento)
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Jobs', 'app/jobs'
  add_group 'Channels', 'app/channels'
end

SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
```

### Reportes

```bash
# Generar reporte HTML
open coverage/index.html

# Ver resumen
bundle exec rspec
```

---

## 🧪 Mocking y Time Travel

### Timecop

```ruby
# Freeze time
Timecop.freeze(Time.zone.now) do
  # Código que usa Time.current
end

# Travel to specific time
Timecop.travel(Time.zone.parse('2024-01-01 12:00:00')) do
  # Código ejecutado en 2024
end

# Return to current time
Timecop.return
```

### WebMock (si se añade)

```ruby
# Mock HTTP requests
stub_request(:get, "https://api.example.com/data")
  .to_return(status: 200, body: { success: true }.to_json)
```

---

## 📋 Resumen de Cobertura

| Archivo | Líneas | Cobertura | Comentario |
|---------|--------|-----------|------------|
| `app/models/product.rb` | 126 | ~90% | Buen testeo |
| `app/controllers/admin/products_controller.rb` | 203 | ~85% | Cobertura parcial |
| `app/models/user.rb` | 115 | ~80% | Faltan tests para broadcasts |
| `app/helpers/application_helper.rb` | 211 | ~70% | Tests parciales |

---

## 🚨 Errores Comunes

1. **Forgot to clean DB between tests**
   ```ruby
   # Asegúrate de usar DatabaseCleaner
   around(:each) do |example|
     DatabaseCleaner.cleaning { example.run }
   end
   ```

2. **FactoryBot not loaded**
   ```ruby
   # En rails_helper.rb
   config.include FactoryBot::Syntax::Methods
   ```

3. **Devise helpers in controller tests**
   ```ruby
   # Usar include Devise::Test::ControllerHelpers o IntegrationHelpers
   ```

4. **Broadcast assertions failing**
   ```ruby
   # Turbo Streams broadcast testing
   expect {
     post admin_products_path, params: valid_params
   }.to have_broadcasted_to('products_catalog')
   ```