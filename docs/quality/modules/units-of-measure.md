# Registro de calidad — Unidades de medida (Delta POS)

- **Alcance:** exclusivamente `/admin/units_of_measure` y su relación con `sat_unit_keys`. Listado, modales, validaciones, permisos, filtros, baja lógica y administración por organización.
- **Fuera de alcance:** Productos, Presentaciones, Inventario, conversiones comerciales y cualquier asociación nueva hacia Productos. No se modificó el modelo `Product`.
- **Rama:** `feature/fixes`. **SHA inicial:** `985c26e6d9932e91246bc76c475d96bbd9c2dfd0`.
- **Método:** AI Dev Suite — `ui-ux-pro-max`, `impeccable-audit` y `ponytail-engineering`.
- **Estado:** implementación, migración limpia, RSpec focalizado, RuboCop focalizado y flujos básicos de navegador **PASARON** en `9e81ac3`. CI global y aceptación visual independiente **PENDIENTES / CON FALLOS EXTERNOS**. **NO CERRADO**.

## Alcance funcional implementado

- Campos de captura: código interno, nombre, abreviatura, descripción, unidad SAT, precisión decimal y estado.
- La precisión decimal de 0 a 6 determina si se permiten fracciones; no hay un interruptor contradictorio.
- Catálogo `units_of_measure` por organización, con referencia a `sat_unit_keys`, unicidad de código sin considerar mayúsculas y validaciones de modelo y base de datos.
- Pantalla principal con búsqueda, filtros por estado, SAT y fracciones; paginación según preferencias, indicadores resumidos y diseño adaptable.
- Alta y edición en modal Turbo; detalle en modal; baja lógica con confirmación SweetAlert2 y retroalimentación localizada.
- Autorización Pundit, seis permisos granulares, traducciones `es/en/ko`, rastreo PaperTrail y pruebas de modelos y requests agregadas.

## Hallazgos y seguimiento permanente

| ID | Prioridad | Riesgo / área evaluada | Adecuación | Verificación |
|---|---|---|---|---|
| UOM-001 | P1 | Nuevo recurso sin dueño en registro de calidad modular bloqueaba CI de I18n | Registro, ruta y expediente publicados | PASÓ auditoría I18n y YAML en CI #42634181504 |
| UOM-002 | P1 | Posible acceso cruzado entre empresas | Scope por `organization_id`, request de aislamiento y unicidad por empresa | PASÓ request de aislamiento en focalizado #42634181533 |
| UOM-003 | P1 | Claves SAT retiradas o fuera de vigencia | Solo permitir asociar claves `SatUnitKey.current` en nuevas asociaciones | PASÓ rechazo de clave caducada; borrado SAT requiere test adicional |
| UOM-004 | P2 | Inconsistencias visuales y de interacción | Modal Stimulus, dropdown Delta, errores por campo y skeleton | PASÓ Chrome: CRUD y geometría 320/390/768/1440; WCAG manual pendiente |
| UOM-005 | P2 | Entradas duplicadas y códigos inconsistentes | Normalización, modelo e índice único parcial PostgreSQL | PASÓ modelo y migración limpia; concurrencia real pendiente |
| UOM-006 | P2 | Integridad de precisión y baja lógica | CHECK decimal/estado, `deleted_at`, PaperTrail | PASÓ modelos y baja lógica; rastreo PaperTrail no probado aisladamente |
| UOM-007 | P2 | Traducciones o etiquetas incompletas | Locales es, en y ko | PASÓ paridad I18n; traducción semántica manual pendiente |
| UOM-008 | P2 | Permisos de lectura y escritura por rol | `CatalogPolicy` + códigos `units_of_measure.*` | PASÓ acceso denegado y rol autorizado; matriz granular completa pendiente |

### UOM-009 · P1 · Compatibilidad de esquema histórico
- **Hallazgo confirmado por RSpec focalizado:** `db:drop db:create db:migrate` cargó el esquema previo y marcó como aplicada la versión antigua de creación de `units_of_measure` sin crear la tabla, provocando `PG::UndefinedTable`.
- **Adecuación:** incluir el nuevo catálogo en `db/schema.rb`, conservar la migración junto a Productos y añadir migración defensiva `20261110130100` para bases ya migradas sin tabla.
- **Verificación:** PASÓ preparación desde cero y batería focalizada en #42634181533; actualización de una base legada ya desplegada aún pendiente de prueba independiente.

## Evidencias y límites

- **PASÓ:** [Units of measure CI #42634181533](https://github.com/AliRodri1992/sales_point/actions/runs/42634181533) en SHA `9e81ac30f9f76ca5c156e902d85a8ec4279d8d0e`: 15 ejemplos (modelos + solicitudes + navegador Chrome), 0 fallos; RuboCop focalizado aprobado. Se verificaron altas, errores, consulta, edición y cierre con Escape, además de límites del panel en 320/390/768/1440 px.
- **FALLÓ inicialmente:** CI #42625619635 (`Rails I18n and YAML audit`) y Languages CI #42625619623 (`Languages locale integrity`) por `Unowned admin resource: units_of_measure`. Se añadió este registro para corregir la causa. No equivale a comprobar que CI ya pasó.
- **PASÓ:** controles transversales de seguridad e I18n/YAML; migraciones en CI fresco para SHAs anteriores y batería focalizada con base reconstruida. **CI global** #42634181504 sigue fallando RuboCop por infracciones de otros módulos. La falla histórica de RSpec en Clientes (`GET /admin/clients` devuelve 403 frente a 200 esperado) está fuera del límite propio de Unidades.
- **PENDIENTE:** verificación manual visual y accesibilidad en navegador (zoom 200 %, lector de pantalla, contraste y manejo completo del foco), evidencia de migración desde base antigua en producción, revisión independiente y CI global verde.
- **Revisión independiente y responsable de aceptación:** PENDIENTES.

## Criterio de cierre

Mantener **NO CERRADO** hasta que todas las comprobaciones del estándar estén verdes, los hallazgos tengan regresiones y se haya realizado la auditoría visual real. Ninguna modificación implica aceptación automática ni fusión a `development`.

[Estándar modular](../module-quality-standard.md) · [Índice](README.md).
