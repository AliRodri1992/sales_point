# NEXO POS - Documentación Técnica

Bienvenido a la documentación técnica oficial de **NEXO POS**.

---

## 🧭 Índice Rápido

### 📖 Guías Principales
- [Instalación](installation.md) - Paso a paso para instalar el sistema
- [Estructura del Proyecto](project-structure.md) - Organización de archivos
- [Arquitectura](architecture.md) - Diagramas y flujos del sistema

### 🛠️ Configuración
- [Configuración](configuration.md) - Variables y settings del sistema
- [Docker](docker.md) - Despliegue y containers
- [Seguridad](security.md) - Prácticas de seguridad

### 📚 Base de Datos
- [ERD](databases/erd.md) - Diagrama de entidades
- [Modelos](databases/models.md) - Documentación de cada modelo

### 📦 Módulos Funcionales
- [Productos](modules/products.md) - Gestión completa de productos
- [Categorías](modules/categories.md) - Organización de productos
- [Idiomas](modules/languages.md) - Multi-idioma
- [Usuarios y Roles](modules/users.md) - Autenticación y autorización
- [Dashboard](modules/dashboard.md) - Panel de administración
- [Comunicaciones](modules/communications.md) - Chat en tiempo real
- [Notificaciones](modules/notifications.md) - Sistema de notificaciones
- [Solicitudes Demo](modules/demo-requests.md) - Captura de leads

### 💻 Frontend
- [Estructura Frontend](frontend/structure.md) - Stack y organización

### 🎯 Testing
- [Guía de Testing](testing.md) - Estrategia y ejemplos

### 🆘 Soporte
- [Troubleshooting](troubleshooting.md) - Solución de problemas

---

## 🚀 Inicio Rápido

```bash
# 1. Clonar el repositorio
git clone [url]
cd sale_point

# 2. Instalar dependencias
bundle install
yarn install

# 3. Configurar variables
cp .env.example .env  # Si existe
# Editar variables de entorno

# 4. Configurar base de datos
bin/rails db:create db:migrate

# 5. Iniciar el servidor
bin/rails server

# 6. Acceder a http://localhost:3000
```

---

## 📚 Tabla de Contenidos Completa

1. **Arquitectura**
   - Diagramas de sistema
   - Flujos de petición HTTP
   - Relaciones entre componentes

2. **Base de Datos**
   - Modelo ERD
   - Tablas principales
   - Relaciones y referencias

3. **Modelos**
   - Documentación detallada
   - Validaciones
   - Scopes y métodos

4. **Módulos**
   - Cada módulo funcional documentado
   - Endpoints y parámetros
   - Ejemplos de uso

5. **Autenticación**
   - Devise configurado
   - Roles y permisos
   - Seguridad de sesiones

6. **Frontend**
   - Stimulus Controllers
   - Tailwind CSS
   - Componentes

7. **Testing**
   - Estructura de specs
   - Factories
   - Comandos útiles

---

## 📞 Contacto

Desarrollado por Ivan Rodriguez.  
Para preguntas técnicas o contribuciones, abrir un issue en GitHub.

---

## 📄 Licencia

MIT License - Libre uso, modificación y distribución.