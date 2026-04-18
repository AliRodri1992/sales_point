# 🛒 Sales Point

Sistema de Punto de Venta (POS) desarrollado con **Ruby on Rails 8**, enfocado en la gestión de ventas, productos, inventario y usuarios para negocios pequeños y medianos.

---

## 🚀 Características

- 📦 Gestión de productos (CRUD completo)
- 🧾 Registro de ventas con detalle de productos
- 📊 Control de inventario en tiempo real
- 👤 Gestión de usuarios
- 🔐 Autenticación con Devise
- 🛡️ Autorización basada en roles con Pundit
- 🌐 Soporte multi-idioma con i18n
- ⚙️ Procesamiento en background con Sidekiq (opcional)
- 🐳 Entorno de desarrollo con Docker
- 🎨 UI moderna con TailwindCSS

---

## 🏗️ Arquitectura del proyecto

app/
├── controllers/
├── models/
├── views/
├── policies/
├── jobs/
├── services/
├── helpers/

---

## 🧰 Tecnologías

- Ruby on Rails 8
- PostgreSQL
- Redis (opcional)
- Docker & Docker Compose
- Devise
- Pundit
- Sidekiq
- TailwindCSS
- I18n

---

## 📦 Instalación

### 1. Clonar el repositorio

git clone https://github.com/AliRodri1992/sales_point.git
cd sales_point

### 2. Variables de entorno

cp .env.example .env

### 3. Docker

docker compose -f docker-compose.dev.yml build
docker compose -f docker-compose.dev.yml up

### 4. Migraciones

docker compose exec web bin/rails db:create db:migrate db:seed

---

## 🧪 Testing

bundle exec rspec

---

## 👤 Autor

Ivan Rodriguez
GitHub: https://github.com/AliRodri1992

---

## 📄 Licencia

MIT
