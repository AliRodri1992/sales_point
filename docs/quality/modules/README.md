# Índice de expedientes de calidad — Delta POS

**Cobertura documental inicial:** 31 ámbitos/módulos (30 registros nuevos y Sucursales preexistente).  
**Estado:** Expedientes creados; **no equivale a auditorías realizadas ni módulos verificados**.  
**Inicio:** 2026-11-08 · **Rama de implementación:** `feature/fixes`.

Consulta primero el [estándar de calidad modular](../module-quality-standard.md) y la [plantilla](../module-audit-template.md). Cada módulo tendrá su propio registro permanente; una auditoría futura debe **actualizarlo**, nunca crear un documento paralelo con los mismos hallazgos.

## Administración y acceso

| Módulo | Ruta principal | Expediente |
|---|---|---|
| Sucursales | `/admin/branches` | [Sucursales](branches.md) |
| Usuarios e invitaciones | `/admin/users` | [Usuarios](users.md) |
| Autenticación y recuperación | `/users/sign_in` | [Autenticación](authentication.md) |
| Roles y permisos | `/system_roles` | [Roles](system-roles.md) |
| Onboarding | `/admin/onboarding` | [Onboarding](onboarding.md) |
| Mi perfil | `/admin/profile` | [Perfil](profile.md) |
| Configuración general | `/admin/general_settings` | [Configuración](general-settings.md) |
| Contactos de organización | `/admin/organization/contacts` | [Contactos](organization-contacts.md) |
| Idiomas | `/admin/languages` | [Idiomas](languages.md) |
| Navegación y preferencias de tablas | `/admin/sidebar` y `/admin/table_page_preferences/:table_key` | [Navegación](navigation-preferences.md) |
| Dashboard administrativo | `/admin/dashboard` | [Dashboard](dashboard.md) |

## Catálogo, comercial y proveedores

| Módulo | Ruta principal | Expediente |
|---|---|---|
| Productos | `/admin/products` | [Productos](products.md) |
| Categorías | `/admin/categories` | [Categorías](categories.md) |
| Unidades de medida | `/admin/units_of_measure` | [Unidades de medida](units-of-measure.md) |
| Listas de precios | `/admin/price_lists` | [Listas de precios](price-lists.md) |
| Promociones | `/admin/promotions` | [Promociones](promotions.md) |
| Clientes | `/admin/clients` | [Clientes](clients.md) |
| Proveedores y subrecursos | `/admin/suppliers` | [Proveedores](suppliers.md) |
| Solicitudes de demostración | `/admin/demo_requests` y `/demo_requests` | [Demostraciones](demo-requests.md) |

## Compras, inventario y finanzas

| Módulo | Ruta principal | Expediente |
|---|---|---|
| Compras | `/admin/purchase_requests`, `purchase_orders`, recepciones y devoluciones | [Purchases](purchases.md) |
| Inventario | `/admin/inventory` y `/admin/branches/:branch_id/inventories` | [Inventario](inventory.md) |
| Terminales | Acciones `add_terminal` y `change_terminal` en `/admin/branches/:id` | [Terminales](terminals.md) |
| Cuentas por pagar | `/admin/account_payables` | [Cuentas por pagar](accounts-payable.md) |
| Facturas de proveedores | `/admin/supplier_invoices` | [Facturas](supplier-invoices.md) |
| Pagos a proveedores | `/admin/supplier_payments` | [Pagos](supplier-payments.md) |
| Notas de crédito de proveedores | `/admin/supplier_credit_notes` | [Notas de crédito](supplier-credit-notes.md) |

> **Terminales:** actualmente no se identificó una ruta CRUD administrativa independiente; sus operaciones visibles están embebidas en Sucursales. Su expediente no supone la existencia de un módulo autónomo. **Inventario** sí dispone de rutas propias anidadas y se auditará internamente por separado.

## Comunicación, ayuda y sitio público

| Módulo | Ruta principal | Expediente |
|---|---|---|
| Plantillas de correo y remitentes | `/admin/email_templates` | [Plantillas](email-templates.md) |
| Notificaciones | `/notifications` (acciones disponibles) | [Notificaciones](notifications.md) |
| Conversaciones y chat | `/conversations` | [Chat](conversations.md) |
| Asistente | `/admin/assistant/reply` | [Asistente](assistant.md) |
| Guía y ayuda | `/admin/guide` | [Guía](guide.md) |
| Páginas públicas | `/`, `/privacy` y rutas públicas | [Páginas públicas](public-pages.md) |

## Proceso de incorporación de módulos futuros

1. Confirmar rutas reales y dueño funcional; agregar un registro con la plantilla y enlazarlo aquí.
2. Definir explícitamente el límite: auditar el módulo propio; en módulos vecinos, solo contratos de integración.
3. Inventariar pantallas, permisos, modelos, vistas, locales y specs sin suponer que todas las rutas CRUD existen.
4. Registrar hallazgos permanentes con causas raíz y resultados ejecutados; no copiar diagnósticos antiguos como si fueran nuevos.
5. Solo declarar **CERRADO** cuando RSpec, RuboCop, seguridad, I18n, CI del SHA final y pruebas UI aplicables se hayan verificado realmente.

**La existencia de un expediente es un control documental, no un certificado de calidad.** Ninguno de los expedientes nuevos se marcó como auditado/verificado/cerrado por el simple hecho de crearlo.

## Indicadores de seguimiento

| Indicador | Estado al crear el índice |
|---|---|
| Ámbitos/módulos inventariados con expediente | 31 |
| Expedientes nuevos | 30 |
| Sucursales | [Implementado, pendiente de verificación](branches.md) |
| Restantes | Inventariados, no verificados |
| Cierres técnicos certificados por este trabajo | 0 |
