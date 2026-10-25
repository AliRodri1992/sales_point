# 🛒 Sales Point

A modern **Point of Sale (POS)** system built with **Ruby on Rails 8**, designed for inventory management, sales tracking, and user administration for small to medium-sized businesses.

## Política de commits de agentes de IA

Este repositorio aplica las instrucciones de [AGENTS.md](AGENTS.md). Por regla general, cada commit debe incluir **al menos cinco archivos realmente modificados y relacionados**.

**Excepción única:** se permite un commit de exactamente un archivo cuando sea necesario modificar el esquema Rails existente `db/schema.rb`. Debe ser una modificación real del esquema (no un archivo nuevo, renombrado o eliminado), sin otros archivos incluidos en el commit. La revisión humana o del agente debe justificar la necesidad del cambio; la herramienta automatizada solamente valida la ruta, el tipo de modificación y la cantidad de archivos. Los commits de dos, tres o cuatro archivos siguen prohibidos.

La comprobación local utiliza `bash bin/check-commit-min-files --staged` y el hook Overcommit configurado en `.overcommit.yml`. Las pruebas del control están en `test/commit_min_files_test.sh`; GitHub Actions comprueba la regla mediante `.github/workflows/commit-policy.yml`. No introducir archivos falsos o cambios irrelevantes para alcanzar el mínimo.



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

## Pre-push: RSpec mediante Docker Compose

El hook `bin/overcommit-rspec` **nunca ejecuta Rails en macOS**. Comprueba que Docker
Desktop y Docker Compose v2 estén disponibles y usa `docker-compose.dev.yml`:

- Si `web` está ejecutándose: `docker compose -f docker-compose.dev.yml exec -T web`.
- Si `web` está detenido: `docker compose -f docker-compose.dev.yml run --rm -T web`,
  que inicia `db` y `redis` como dependencias.
- Dentro del contenedor fuerza `RAILS_ENV=test`, `POSTGRES_HOST=db`, elimina
  `DATABASE_URL`, ejecuta `bin/rails db:prepare` y después `bundle exec rspec`.
- Si Docker, PostgreSQL o RSpec fallan, **se bloquea el push con un error visible**.
  No hay ejecución alternativa en el Mac ni desactivación de verificaciones.

Para ejecutar o diagnosticar manualmente:

```bash
bash test/overcommit_rspec_test.sh        # Pruebas aisladas del hook: no requieren Docker
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml up -d db redis web
docker compose -f docker-compose.dev.yml exec -T web env RAILS_ENV=test bin/rails db:prepare
docker compose -f docker-compose.dev.yml exec -T web env RAILS_ENV=test bundle exec rspec
```

Cuando Overcommit advierta que cambió el script, **revísalo** antes de ejecutar
`bundle exec overcommit --sign pre-push`.

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