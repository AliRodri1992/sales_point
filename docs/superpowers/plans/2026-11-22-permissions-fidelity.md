# Permissions Fidelity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Integrar la última plantilla en Administrar permisos y Ver permisos.

**Architecture:** Mantener Pundit, controlador Rails, formulario y Stimulus; separar estructura, presentación de matriz, información del rol e interacciones sin duplicar inputs.

**Tech Stack:** Rails 8.1, Tailwind 4, Stimulus, RSpec, PostgreSQL.

**Spec:** `docs/superpowers/specs/2026-11-22-permissions-fidelity-design.md`

## Global Constraints

- Sin nuevas dependencias ni permisos de demostración; SVG inline propios.
- Mantener autorización de administrador, historial autorizado y bloqueo de roles protegidos/compartidos.
- Mantener metadatos, ciclo de vida, validaciones 422 y persistencia de permisos reales.
- Locales es/en/ko, accesibilidad y vista responsive; `feature/fixes` exclusivamente.

## Review Focus

- Una acción inexistente no genera un permiso nuevo; códigos irregulares aparecen en especiales.
- Una selección filtrada no pierde selecciones ocultas; dependencias de acceso siguen vigentes.
- Un administrador no accede a historial ajeno ni a datos de otra organización.
- Cancelar descarte conserva campos y permisos; confirmar restaura cambios o navega.
- Una respuesta 422 conserva valores y selección, muestra errores y no oculta la sección necesaria.

### Task 1: Diseño integrado, matriz y tabs

**Files:** `app/views/system_roles/show.html.erb`, `_form.html.erb`, `_permissions.html.erb`, `_permission_group.html.erb`, `_permission_card.html.erb`, `app/helpers/role_permission_catalog_helper.rb`, `app/helpers/system_role_breadcrumbs_helper.rb`, CSS de roles, locales y `spec/requests/system_roles_editor_spec.rb`.

- [ ] Añadir regresiones de HTML renderizado: una matriz real con columnas, acciones no estándar en área especial, pestañas autorizadas y contador de usuario limitado a organización.
- [ ] Ejecutar el RSpec focalizado; confirmar RED.
- [ ] Integrar encabezado y footer en una superficie, tabs accesibles y tabla responsive. Mantener un input por permiso y todos los atributos Stimulus existentes.
- [ ] Ejecutar pruebas focalizadas y comprobar vistas a cuatro anchos.

### Task 2: Seguimiento de cambios y revisión

**Files:** `_form.html.erb`, `_permission_review.html.erb`, `_permission_discard.html.erb`, `role_permissions_controller.js`, traducciones, `spec/features/system_roles_editor_browser_spec.rb`.

- [ ] Añadir escenarios que verifiquen contador de altas/bajas y que cancelar el descarte deja la selección intacta; confirmar descarte restaura; volver exige confirmación.
- [ ] Ejecutar pruebas focalizadas y confirmar RED.
- [ ] Implementar revisión fiel, contadores y confirmación con `<dialog>`; conservar envío por Turbo, 422, navegación y cambios de metadatos.
- [ ] Ejecutar pruebas focalizadas y completas, RuboCop, I18n, build JS/CSS; inspección visual y revisión independiente.
- [ ] Registrar resultados reales y publicar commit en `feature/fixes` sin force push; verificar CI del SHA.
