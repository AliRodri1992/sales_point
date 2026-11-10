# Registro de calidad — Inventario

**Estado:** IMPLEMENTADO, PENDIENTE DE VERIFICACIÓN, **NO CERRADO**.  
**Rutas propias:** `/admin/inventory`, `/admin/branches/:branch_id/inventories`, ajustes, y lotes.  
**Rama:** `feature/fixes` · **Auditoría estática:** 2026-11-10 · **SHA de aceptación:** PENDIENTE.
**Procedimiento:** AI Dev Suite — `impeccable-audit`, `ui-ux-pro-max`, `ponytail-engineering`.

## Alcance e integración

Control de existencias por organización y sucursal, filtros de búsqueda y seguimiento, KPIs,
paginación, altas de productos por sucursal, mínimos y máximos, ajustes, lotes, series y movimientos
históricos. Los servicios existentes `Inventories::ApplyMovement`, `Purchases::Receive` y
`Inventories::FefoAllocator` conservan su responsabilidad sobre operaciones transaccionales.

**Límite:** los flujos de Compras, Productos y Sucursales se revisan solo en sus contratos con
Inventario. Los conteos físicos y las transferencias de lotes/series requieren fase independiente,
sin activar controles incompletos.

## Hallazgos y adecuaciones

| ID | Prioridad | Evidencia / diagnóstico | Adecuación implementada o pendiente | Pruebas / estado |
| --- | --- | --- | --- | --- |
| INVENTORY-001 | P1 · PROPIO | Solo existía consulta por sucursal | Panel general `/admin/inventory`, métricas y navegación | Specs añadidas; CI PENDIENTE |
| INVENTORY-002 | P1 · PROPIO | Acceso basado en administrador, sin permiso del recurso; riesgo de rol cruzado de sucursal | `InventoryPolicy` con `inventory.access/view/manage/adjust`, roles globales y por sucursal acotados | Specs de denegación y alcance; CI PENDIENTE |
| INVENTORY-003 | P1 · PROPIO | Consulta anidada sin filtros ni paginación | Búsqueda, estado, seguimiento, KPIs y preferencias por tabla | Specs añadidas; UI PENDIENTE |
| INVENTORY-004 | P2 · PROPIO | Alta y ajustes visibles en todas las filas | Alta desplegable y edición de límites/ajustes compactos | Navegador PENDIENTE |
| INVENTORY-005 | P2 · PROPIO | Ajuste carecía de referencia editable | Campo de motivo/referencia opcional conservado en movimiento | Spec de registro; CI PENDIENTE |
| INVENTORY-006 | P2 · PROPIO | Sin filtros avanzados ni chips de filtros activos | Panel avanzado, criterios seleccionados desmontables y búsqueda automática | Specs + navegador PENDIENTE |
| INVENTORY-007 | P1 · INTEGRACIÓN | Traslado entre sucursales con trazabilidad por lotes/series aún sin flujo operativo seguro | No activar pantalla; diseñar contrato transaccional y conciliación | PENDIENTE |
| INVENTORY-008 | P1 · PROPIO | Sin conteo físico integral ni integración con Ventas | Fase futura; no editar stock directamente | PENDIENTE |
| INVENTORY-009 | P2 · PROPIO | Accesibilidad, UX y traducciones requieren evaluación integral | Locales es/en/ko, mensajes por campo y controles de navegación | Navegador e I18n PENDIENTE |

## Casos obligatorios de aceptación

| Dimensión | Criterio | Evidencia |
| --- | --- | --- |
| Operación | Altas, límites, ajustes, lote, serie y estados de sucursal con errores 422 | Specs focalizadas, ejecución PENDIENTE |
| Datos y autorización | Rol que concedió permiso, alcance de sucursal/organización, aislamiento, soft delete | Specs nuevas, ejecución PENDIENTE |
| UX | Móvil, teclado, foco, contraste, zoom 200 %, vacíos, SweetAlert y controles de filtros | Navegador PENDIENTE |
| Rendimiento | Paginación, conteo SQL y última ventana de movimientos sin N+1 | Specs existentes, ejecución PENDIENTE |
| I18n | Español, inglés y coreano sin llaves ausentes | CI PENDIENTE |

## Verificaciones y dictamen

- **RSpec focalizado / completo:** NO EJECUTADO directamente; ejecución CI PENDIENTE.
- **RuboCop / seguridad / I18n:** NO CONFIRMADOS en SHA final.
- **Navegador real móvil y escritorio:** NO EJECUTADO.
- **GitHub Actions:** múltiples jobs del primer commit fallaron por expediente de calidad duplicado, además de regresiones ajenas en Usuarios, Clientes y Configuración General. Esta corrección unifica el registro sin eliminar los fallos ajenos; **el CI final debe volver a comprobarse**.
- **Revisión independiente:** PENDIENTE.
- **Dictamen:** **NO CERRADO**. Implementación publicada, aceptación bloqueada por CI y regresiones de UI.

Política: [Estándar modular](../module-quality-standard.md) · [Plantilla](../module-audit-template.md).
