# 🛒 Sales Point

A modern **Point of Sale (POS)** system built with **Ruby on Rails 8**, designed for inventory management, sales tracking, and user administration for small to medium-sized businesses.

## Política de commits

Los commits pueden incluir **uno o más archivos**, según lo requiera el cambio. No se impone un número mínimo ni una excepción exclusiva para `db/schema.rb`. Consulta [AGENTS.md](AGENTS.md) para las pautas de revisión y calidad.

Overcommit y GitHub Actions mantienen las comprobaciones de código y seguridad, sin bloquear commits por su cantidad de archivos.

---

## 🚀 Features

### 📦 Product Management
- Complete product catalog with advanced search and filtering
- Real-time inventory tracking with low stock alerts
- Product categorization and SAT unit management
- Support for featured products and status management
- Gross margin and total value calculations

### 🧾 Sales System
- Complete sales registration with product details
- Automatic price calculation with taxes
- Sales history and reporting
- Multi-language support

### ⚙️ Administration
- User management and role-based access control
- Multi-language configuration (i18n)
- System categories and fiscal regimes
- Configuration management

### 📊 Real-time Updates
- Turbo Streams for live data synchronization
- SweetAlert2 notifications
- Real-time product catalog updates

---

## 🏗️ Architecture

```
app/
├── controllers/
│   └── admin/              # Admin controllers
├── models/                 # Database models
├── views/
│   └── admin/              # Admin panel views
├── policies/               # Pundit authorization policies
├── jobs/                   # Background jobs
├── services/               # Business logic services
├── helpers/                # View helpers
└── channels/               # ActionCable channels

db/
├── migrate/                # Database migrations
├── schema.rb
└── seeds.rb

spec/
├── models/                 # Model tests
├── requests/               # Request/controller tests
├── helpers/                # Helper tests
└── factories/              # Test factories
```

---

## 📋 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/users/sign_in` | User sign in |
| DELETE | `/users/sign_out` | User sign out |

### Products (Admin)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/products` | List products |
| POST | `/admin/products` | Create product |
| GET | `/admin/products/new` | New product form |
| GET | `/admin/products/:id` | Show product |
| GET | `/admin/products/:id/edit` | Edit product form |
| PATCH | `/admin/products/:id` | Update product |
| DELETE | `/admin/products/:id` | Delete product (soft delete) |

### Categories (Admin)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/categories` | List categories |
| POST | `/admin/categories` | Create category |

### Languages (Admin)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/languages` | List languages |
| POST | `/admin/languages` | Create language |

---

## 🛠️ Technologies

### Backend
- **Ruby on Rails 8** - Web framework
- **PostgreSQL** - Database
- **Devise** - Authentication
- **Pundit** - Authorization
- **Sidekiq** - Background processing
- **Turbo Streams** - Real-time updates

### Frontend
- **Tailwind CSS** - Styling
- **Stimulus** - JavaScript framework
- **SweetAlert2** - Notification system
- **Hotwire** - Modern web development

### Testing
- **RSpec** - Testing framework
- **FactoryBot** - Test factories
- **Shoulda Matchers** - Model matchers

---

## 📦 Installation

### 1. Clone the repository

```bash
git clone https://github.com/AliRodri1992/sales_point.git
cd sales_point
```

### 2. Environment setup

```bash
cp .env.example .env
# Edit .env with your credentials
```

### 3. Docker setup (recommended)

```bash
docker compose -f docker-compose.dev.yml build
docker compose -f docker-compose.dev.yml up
```

### 4. Database setup

```bash
docker compose exec web bin/rails db:create db:migrate db:seed
```

### 5. Run tests

```bash
docker compose exec web bundle exec rspec
```

---

## Overcommit local y pruebas completas en CI

Los hooks de Overcommit se mantienen ligeros para que **commits y pushes no
dependan de Docker, PostgreSQL ni de la duración de RSpec**:

- `pre-commit`: comprueba espacios en blanco sobrantes.
- `pre-push`: no ejecuta RSpec, Brakeman, BundlerAudit ni otros procesos largos.
- `GitHub Actions / CI`: ejecuta **toda la suite RSpec**, RuboCop, Brakeman,
  BundlerAudit y las verificaciones de traducciones. Un error hace fallar CI.

Una comprobación de configuración protege este contrato en
`.github/workflows/pre-push-hook-tests.yml`.

```bash
bundle exec overcommit --install
bundle exec overcommit --sign
bundle exec overcommit --run pre-push
ruby test/overcommit_configuration_test.rb
```

La suite también puede ejecutarse de manera explícita, **fuera del push** y con
la base de pruebas aislada del entorno de desarrollo:

```bash
bash bin/overcommit-rspec
```

Para impedir integrar cambios con CI rojo, configura como *required checks*
los jobs **RSpec**, **RuboCop**, **Security scans** y **Rails I18n and YAML audit**
en la protección de la rama de integración. El push solo publica el commit:
no puede esperar el resultado completo de un CI que empieza después.

---

## 🧪 Testing

### Run all tests

```bash
bundle exec rspec
```

### Run specific tests

```bash
# Model tests
bundle exec rspec spec/models/product_spec.rb

# Request/controller tests
bundle exec rspec spec/requests/admin/products_spec.rb

# Helper tests
bundle exec rspec spec/helpers/application_helper_spec.rb
```

### Test output format

```bash
bundle exec rspec --format documentation
```

---

## 🚀 Deployment

### Required configuration

1. Production environment variables
2. PostgreSQL database
3. Redis for Sidekiq
4. SSL/TLS configured

### Useful commands

```bash
# Precompile assets
RAILS_ENV=production bundle exec rails assets:precompile

# Run database migrations
RAILS_ENV=production bundle exec rails db:migrate

# Start the server
RAILS_ENV=production bundle exec rails server -b 0.0.0.0
```

---

## 📖 API Documentation

OpenAPI/Swagger documentation is available at `/api-docs` when the server is running.

---

## 👤 Author

Ivan Rodriguez
GitHub: https://github.com/AliRodri1992

---

## 📄 License

MIT License - Feel free to use, modify, and distribute this software.