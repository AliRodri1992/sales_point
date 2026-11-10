# Registro de calidad — Inventarios

- **Módulo:** inventario general, por sucursal y trazabilidad de lotes.
- **Rama:** `feature/fixes`.
- **Metodología:** AI Dev Suite — `impeccable-audit`, `ui-ux-pro-max`, `ponytail-engineering`.
- **Evidencia:** inspección estática de código; no equivale a un recorrido de navegador.
- **Estado:** IMPLEMENTADO — PENDIENTE DE PRUEBAS Y CI EN SHA FINAL.

| ID | Prioridad | Hallazgo de la revisión | Adecuación | Verificación |
| --- | --- | --- | --- | --- |
| INVENTORY-001 | Alta | Inventarios accesibles solo dentro de cada sucursal; no hay consulta transversal | Nuevo `/admin/inventory` y enlace lateral | Request specs |
| INVENTORY-002 | Alta | Controlador restringido al rol de administrador, sin permiso independiente | `InventoryPolicy`, alcance organizacional y por sucursal, permisos separados de consulta y gestión | Requests de rechazo |
| INVENTORY-003 | Alta | Listado por sucursal completo sin paginación ni filtros | Búsqueda, estatus, seguimiento, KPIs, preferencias y paginación | Requests + navegador |
| INVENTORY-004 | Media | Formulario de alta y muchos ajustes ocupan cada fila continuamente | Panel de alta y controles de ajuste/umbrales desplegables, edición puntual por registro | Navegador |
| INVENTORY-005 | Media | Ajuste no solicita referencia contextual | Campo de referencia opcional persistido en `InventoryMovement` | Request de persistencia |
| INVENTORY-006 | Media | No existían etiquetas de filtros activos ni filtros avanzados | Chips para quitar criterios y panel avanzado compacto | Request + navegador |
| INVENTORY-007 | Alta | La transferencia entre sucursales requiere diseño de trazabilidad y conciliación para lotes/series | No exponer el flujo incompleto; documentar dependencia | PENDIENTE |
| INVENTORY-008 | Alta | Conteos físicos e integración con ventas no tienen flujo completo | Definir fases posteriores antes de su activación | PENDIENTE |
| INVENTORY-009 | Media | Falta verificación de interfaz accesible, traducciones y manejo de errores | Nuevas cadenas es/en/ko y atributos de formulario | PENDIENTE: navegador/CI |

## Contratos que deben conservarse

Las recepciones siguen aportando stock exclusivamente por `Purchases::Receive`.
Los movimientos históricos siguen siendo inmutables. Las existencias por sucursal no
se editan directamente y los productos con seguimiento serial no tienen formulario
de ajuste manual.

## Criterio de cierre

Ejecutar RSpec focalizado, RuboCop, carga de locales, `zeitwerk:check`, verificación
manual de frontend y GitHub Actions en el commit definitivo. Registrar cualquier fallo
por ID sin marcarlo como resuelto antes de comprobarlo.
