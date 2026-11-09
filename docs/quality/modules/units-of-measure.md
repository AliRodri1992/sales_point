# Registro de calidad — Unidades de medida (Delta POS)

- **Alcance:** exclusivamente `/admin/units_of_measure` y su relación con `sat_unit_keys`. Listado, modales, validaciones, permisos, filtros, baja lógica y administración por organización.
- **Fuera de alcance:** Productos, Presentaciones, Inventario, conversiones comerciales y cualquier asociación nueva hacia Productos. No se modificó el modelo `Product`.
- **Rama:** `feature/fixes`. **SHA inicial:** `985c26e6d9932e91246bc76c475d96bbd9c2dfd0`.
- **Método:** AI Dev Suite — `ui-ux-pro-max`, `impeccable-audit` y `ponytail-engineering`.
- **Estado:** implementación publicada; controles de regresión y aceptación **PENDIENTE**. **NO CERRADO**.

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
| UOM-001 | P1 | Nuevo recurso sin dueño en registro de calidad modular bloquea CI de I18n | Registrar módulo, ruta y expediente | PENDIENTE de CI después de corrección |
| UOM-002 | P1 | Posible acceso cruzado entre empresas | Scope por `organization_id`, request de aislamiento y unicidad por empresa | PENDIENTE RSpec |
| UOM-003 | P1 | Claves SAT retiradas o fuera de vigencia | Solo permitir asociar claves `SatUnitKey.current` en nuevas asociaciones | PENDIENTE RSpec |
| UOM-004 | P2 | Inconsistencias visuales y de interacción | Reutilizar modal Stimulus, dropdown Delta, helpers de campo, skeleton y mensajes | PENDIENTE prueba navegador |
| UOM-005 | P2 | Entradas duplicadas y códigos inconsistentes | Normalización, modelo e índice funcional parcial PostgreSQL | PENDIENTE migración y pruebas |
| UOM-006 | P2 | Integridad de precisión y baja lógica | CHECK de decimal 0..6 y estado, `deleted_at`, PaperTrail | PENDIENTE pruebas |
| UOM-007 | P2 | Traducciones o etiquetas incompletas | Locales es, en y ko | PENDIENTE auditoría I18n |
| UOM-008 | P2 | Permisos de lectura y escritura por rol | `CatalogPolicy` + códigos `units_of_measure.*` | PENDIENTE regresión de permisos |

## Evidencias y límites

- **PASÓ:** creación del commit en GitHub en `feature/fixes`; existencia de los archivos de implementación y pruebas.
- **FALLÓ inicialmente:** CI #42625619635 (`Rails I18n and YAML audit`) y Languages CI #42625619623 (`Languages locale integrity`) por `Unowned admin resource: units_of_measure`. Se añadió este registro para corregir la causa. No equivale a comprobar que CI ya pasó.
- **PENDIENTE:** ejecución focalizada RSpec (modelo, requests, aislamiento, permisos y navegadores), RuboCop, migraciones desde cero, análisis de seguridad, CI del SHA final, validación manual de responsive 320/390/768/1440, zoom 200 %, foco, Escape y lector de pantalla.
- **PENDIENTE:** revisión independiente y asignación de responsable de aceptación.

## Criterio de cierre

Mantener **NO CERRADO** hasta que todas las comprobaciones del estándar estén verdes, los hallazgos tengan regresiones y se haya realizado la auditoría visual real. Ninguna modificación implica aceptación automática ni fusión a `development`.

[Estándar modular](../module-quality-standard.md) · [Índice](README.md).
