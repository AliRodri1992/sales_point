# 🛒 Sales Point

Sistema de Punto de Venta (POS) desarrollado con **Ruby on Rails 8**, enfocado en la gestión de ventas, productos, inventario y usuarios para negocios pequeños y medianos.

---

## 🚀 Características

### 📦 Gestión de Productos
- Catálogo de productos con búsqueda y filtrado avanzado
- Gestión de stock y precios
- Soporte para categorías y unidades SAT
- Campos de margen y valor total
- Estados y productos destacados

### 🧾 Sistema de Ventas
- Registro de ventas con detalle de productos
- Cálculo automático de precios con impuestos
- Historial de ventas

### ⚙️ Configuración
- Gestión de idiomas (multilenguaje)
- Gestión de categorías de productos
- Configuración de unidades SAT
- Tipos de régimen fiscal

### 🔐 Seguridad
- Autenticación con Devise
- Autorización basada en roles con Pundit
- Roles: admin, empleado, supervisor

### 📊 Interfaz de Usuario
- Dashboard administrativo
- UI moderna con TailwindCSS
- Notificaciones en tiempo real con Turbo Streams
- Mensajes flash como SweetAlert2 toasts

---

## 🏗️ Arquitectura del proyecto

```
app/
├── controllers/
│   └── admin/              # Controladores administrativos
├── models/                 # Modelos Prisma estilo Rails
├── views/
│   └── admin/              # Vistas del panel de administración
├── policies/               # Políticas de autorización con Pundit
├── jobs/                   # Trabajos en background
├── services/               # Servicios de negocio
├── helpers/                # Helpers de vistas
└── channels/               # Canales de ActionCable para Turbo Streams

db/
├── migrate/                # Migraciones
├── schema.rb
└── seeds.rb

spec/
├── models/                 # Tests de modelos
├── requests/               # Tests de requests/controladores
├── helpers/                # Tests de helpers
└── factories/              # Factories para tests
```

---

## 📋 Endpoints principales (v1/api)

### Autenticación
| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/users/sign_in` | Iniciar sesión |
| DELETE | `/users/sign_out` | Cerrar sesión |

### Productos (Admin)
| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/admin/products` | Listar productos |
| POST | `/admin/products` | Crear producto |
| GET | `/admin/products/:id` | Ver producto |
| PATCH | `/admin/products/:id` | Actualizar producto |
| DELETE | `/admin/products/:id` | Eliminar producto (soft delete) |

### Categorías (Admin)
| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/admin/categories` | Listar categorías |
| POST | `/admin/categories` | Crear categoría |

### Idiomas (Admin)
| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/admin/languages` | Listar idiomas |
| POST | `/admin/languages` | Crear idioma |

---

## 🛠️ Tecnologías

### Backend
- **Ruby on Rails 8** - Framework principal
- **PostgreSQL** - Base de datos
- **Devise** - Autenticación
- **Pundit** - Autorización
- **Sidekiq** - Procesamiento en background
- **Turbo Streams** - Actualizaciones en tiempo real

### Frontend
- **TailwindCSS** - Estilos
- **Stimulus** - Interactividad
- **SweetAlert2** - Notificaciones
- **Hotwire** - Sin JavaScript adicional

### Testing
- **RSpec** - Tests
- **FactoryBot** - Factories
- **Shoulda Matchers** - Matchers

---

## 📦 Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/AliRodri1992/sales_point.git
cd sales_point
```

### 2. Variables de entorno

```bash
cp .env.example .env
# Editar .env con tus credenciales
```

### 3. Docker (recomendado)

```bash
docker compose -f docker-compose.dev.yml build
docker compose -f docker-compose.dev.yml up
```

### 4. Migraciones y seed

```bash
docker compose exec web bin/rails db:create db:migrate db:seed
```

### 5. Ejecutar tests

```bash
docker compose exec web bundle exec rspec
```

---

## 🧪 Testing

### Ejecutar todos los tests

```bash
bundle exec rspec
```

### Ejecutar tests específicos

```bash
# Test de modelo
bundle exec rspec spec/models/product_spec.rb

# Test de controlador
bundle exec rspec spec/requests/admin/products_spec.rb

# Test de helper
bundle exec rspec spec/helpers/application_helper_spec.rb
```

### Coverage

```bash
bundle exec rspec --format documentation
```

---

## 🚀 Deploy

### Configuración necesaria

1. Variables de entorno de producción
2. Base de datos PostgreSQL
3. Redis para Sidekiq
4. SSL/TLS configurado

### Comandos útiles

```bash
# Precompile assets
RAILS_ENV=production bundle exec rails assets:precompile

# Migrar base de datos
RAILS_ENV=production bundle exec rails db:migrate

# Ejecutar servidor
RAILS_ENV=production bundle exec rails server -b 0.0.0.0
```

---

## 📖 Documentación API

La API está documentada con Swagger/OpenAPI. Acceder a `/api-docs` cuando el servidor esté corriendo.

---

## 👤 Autor

Ivan Rodriguez
GitHub: https://github.com/AliRodri1992

---

## 📄 Licencia

MIT - Puedes usar, modificar y distribuir este software libremente.