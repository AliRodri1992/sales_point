# NEXO POS - Documentación Técnica

Bienvenido a la documentación técnica de **NEXO POS**, una plataforma Business OS desarrollada con Ruby on Rails 8.

---

## 📋 Tabla de Contenidos

1. [Arquitectura del Sistema](architecture.md)
2. [Estructura del Proyecto](project-structure.md)
3. [Instalación](installation.md)
4. [Configuración](configuration.md)
5. [Base de Datos](databases/erd.md)
6. [Modelos](databases/models.md)
7. [Autenticación y Autorización](authentication.md)
8. [Módulos del Sistema](modules/)
9. [Frontend](frontend/structure.md)
10. [Testing](testing.md)
11. [Docker y Despliegue](docker.md)
12. [Seguridad](security.md)
13. [Internacionalización](translations.md)
14. [Solución de Problemas](troubleshooting.md)

---

## 🚀 Características Principales

| Característica | Estado | Descripción |
|---------------|--------|-------------|
| Gestión de Productos | ✅ Implementado | CRUD completo con búsqueda, filtros y soft delete |
| Gestión de Categorías | ✅ Implementado | Organización de productos con estados |
| Gestión de Idiomas | ✅ Implementado | Soporte multi-idioma (es, en, ko) |
| Autenticación | ✅ Implementado | Devise + devise-security con session tracking |
| Roles y Permisos | ✅ Implementado | Sistema de roles (system/branch) con UserRole |
| Dashboard Personalizable | ✅ Implementado | Widgets con GridStack y persistencia |
| Notificaciones en Tiempo Real | ✅ Implementado | Turbo Streams + Noticed |
| Chat en Tiempo Real | ✅ Implementado | ActionCable con Turbo Streams |
| Gestión de Usuarios | ✅ Implementado | Registro, login, preferencias, y estados |

---

## 🛠️ Tecnologías

### Backend
- **Ruby**: 3.3.6
- **Rails**: 8.1.3
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq
- **ActionCable**: Solid Cable (producción) / Async (desarrollo)

### Frontend
- ** templating**: ERB
- **CSS**: Tailwind CSS
- **JavaScript**: Stimulus 3.x + esbuild
- **Real-time**: Turbo Streams 8.x
- **Notificaciones**: SweetAlert2

### Seguridad
- **Autenticación**: Devise + devise-security
- **Rate Limiting**: rack-attack
- **Autorización**: Pundit (preparado)
- **Auditoría**: PaperTrail

---

## 🌍 Idiomas Soportados

- Español (es) - Predeterminado
- Inglés (en)
- Coreano (ko)

---

## 📁 Estructura del Proyecto

```
sale_point/
├── app/
│   ├── controllers/           # Controladores de la aplicación
│   │   ├── admin/            # Controladores del panel admin
│   │   ├── users/             # Controladores Devise
│   │   └── *.rb               # Otros controladores
│   ├── models/                # Modelos de dominio
│   ├── services/              # Lógica de negocio
│   ├── jobs/                  # Trabajos en background
│   ├── channels/              # Canales de ActionCable
│   ├── presenters/            # Presenters
│   └── components/            # ViewComponents
├── app/views/
│   ├── admin/                 # Vistas del panel admin
│   ├── devise/                # Vistas de autenticación
│   └── layouts/               # Layouts principales
├── config/
│   ├── initializers/          # Inicializadores
│   ├── locales/               # Archivos de traducción
│   └── *.yml                  # Configuraciones
├── db/
│   ├── migrate/               # Migraciones
│   └── schema.rb              # Esquema actualizado
└── spec/                       # Suite de tests RSpec
```

---

## 📖 Cómo Empezar

1. **Clonar el repositorio**
   ```bash
   git clone [url-del-repositorio]
   cd sale_point
   ```

2. **Instalar dependencias**
   ```bash
   bundle install
   yarn install
   ```

3. **Configurar variables de entorno**
   ```bash
   cp .env.example .env 2>/dev/null || echo "Crear .env manualmente"
   ```

4. **Configurar base de datos**
   ```bash
   bin/rails db:create db:migrate
   ```

5. **Ejecutar tests**
   ```bash
   bundle exec rspec
   ```

6. **Iniciar el servidor**
   ```bash
   bin/dev
   ```

---

## 🤝 Contribución

1. Haz fork del proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Haz commit de tus cambios
4. Ejecuta tests y asegúrate que pasen
5. Haz push a tu fork
6. Abre un Pull Request

---

## 📄 Licencia

MIT License - Ver archivo LICENSE para más detalles.

---

## 📞 Contacto

Desarrollado por Ivan Rodriguez.  
GitHub: https://github.com/AliRodri1992