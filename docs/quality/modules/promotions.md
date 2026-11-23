# Registro de calidad — Promociones

**Estado:** INVENTARIADO, NO VERIFICADO, NO CERRADO.  
**Rutas propias:** `/admin/promotions`
**Código de entrada confirmado/por comprobar al auditar:** `app/controllers/admin/promotions_controller.rb`
**SHA de aceptación:** PENDIENTE · **Responsable/revisor:** por asignar · **Inicio de registro:** 2026-11-08

> Este documento establece el alcance y las puertas de aceptación; **no certifica que se haya realizado la auditoría**, que los archivos de pruebas existan o que CI esté verde. El registro se completa y versiona durante la auditoría del módulo.

## Alcance propio

Configuración y mantenimiento de promociones, vigencias, elegibilidad, combinaciones, conflictos, permisos y mensajes visibles.

Revisar únicamente las rutas y acciones declaradas y sus modelos, vistas, permisos, servicios, JS/CSS, locales es/en/ko y pruebas **directamente utilizados**. Inventariar métodos y rutas reales antes de probar; no presumir que cada operación CRUD existe.

## Límite de integración

Precios, productos y ventas: verificar los datos/promociones expuestos, sin auditar caja, pagos o transacciones de venta.

**Regla de propiedad:** si el error está dentro de otro módulo, registrarlo como EXTERNO en su expediente. Aquí se prueba solo la entrada, salida, restricción y retroalimentación del contrato visible; no se reimplementa el módulo vecino.

## Casos obligatorios al auditar

| Dimensión | Criterio de aceptación | Evidencia |
|---|---|---|
| Funcionalidad | Recorridos principales de las rutas propias, casos negativos, acciones no disponibles y retorno tras errores | PENDIENTE |
| Formularios y servidor | Validaciones del modelo, asteriscos rojos en obligatorios, mensajes individuales debajo de cada campo, sin duplicación/HTML5 required como sustituto | PENDIENTE |
| Autorización y datos | Pundit, aislamiento de organización/rol, soft delete y estados de negocio, cuando apliquen | PENDIENTE |
| UX y UI | Delta POS, vacío/carga/error/422, responsive escritorio/móvil, teclado, foco, zoom 200 % y accesibilidad | PENDIENTE |
| Internacionalización | Textos y mensajes es/en/ko, etiquetas traducidas y persistencia de valores ante 422 | PENDIENTE |
| Calidad | Tests focalizados, regresiones, RuboCop, seguridad, I18n y CI global del SHA final | PENDIENTE |

## Registro de hallazgos

No se han trasladado ni inventado hallazgos en esta apertura. **Esto no significa cero errores.** Al auditar, registrar IDs permanentes `PROMOTIONS-001` en adelante, prioridad P0–P3, clase PROPIO/INTEGRACIÓN/EXTERNO, evidencia (archivo/línea o reproducción), causa raíz, corrección, spec, SHA y estado; conservar los IDs en revisiones posteriores.

| ID | Prioridad | Clase | Evidencia/causa raíz | Prueba | Estado |
|---|---|---|---|---|---|
| **PROMOTIONS-001** | **P2** | **INTEGRACIÓN detectada desde auditoría de Categorías** | `PromotionCondition#same_organization` permite `category.organization_id == nil` y no rechaza `category.deleted_at.present?`; la migración de Categorías conserva filas globales retiradas con `organization_id NULL`. `Admin::PromotionsController#record_params` acepta `category_id`, por lo que un POST manipulado puede enlazar una categoría global legada o retirada. | Requests/model spec: categoría global legada, retirada de la misma organización y ajena; deben rechazarse sin guardar la condición. | **ABIERTO · no es auditoría integral de Promociones** |

## Verificaciones y dictamen

- **RSpec focalizado / completo:** NO EJECUTADO en este registro.
- **RuboCop / seguridad / I18n:** NO EJECUTADO en este registro.
- **Navegador real móvil y escritorio:** NO EJECUTADO en este registro.
- **GitHub Actions / SHA de aceptación:** NO CONFIRMADO.
- **P0/P1 conocidos y resueltos:** NO DETERMINADO.
- **Revisión independiente:** PENDIENTE.
- **Dictamen:** NO CERRADO. Al auditar, agregar comandos, fecha, resultados reales y enlaces de ejecución.

Política: [Estándar modular](../module-quality-standard.md) · [Plantilla ampliada](../module-audit-template.md).

### Seguimiento de integración — reauditoría de Categorías (2026-11-11)

Este registro incorpora **PROMOTIONS-001** como defecto de frontera observado desde Categorías; no representa una auditoría completa de Promociones. La corrección corresponde al dominio `PromotionCondition`: requerir una categoría no retirada y de la misma organización de la promoción. No modificar ni seleccionar categorías legadas globales con `organization_id NULL`.

### Desarrollo comercial — 2026-11-22

- **PROMOTIONS-001:** la prueba `spec/services/products/promotion_targets_spec.rb` reprodujo la aceptación de referencias inactivas en [Products CI #45085475017](https://github.com/AliRodri1992/sales_point/actions/runs/45085475017), SHA `311c0dbc`. El modelo valida organización y estado en nuevas asignaciones sin eliminar referencias históricas. Verificación de esta adecuación: pendiente de CI del nuevo SHA.
- **PROMOTIONS-002 · P1 · PROPIO:** el evaluador aplicaba `all?` a todas las condiciones; dos productos o categorías alternativos impedían cualquier descuento. La misma ejecución reprodujo dos descuentos esperados de 20 que eran 0. Se agrupan por tipo: OR dentro de producto/categoría, AND para las demás condiciones y entre tipos. Verificación: pendiente de CI del nuevo SHA.

### Implementación comercial integrada

- Menú Comercial y permisos propios, pantallas de campañas separadas de Productos, filtros, selección de productos/categorías activos, exclusiones y consulta de historial.
- Estados efectivos, códigos automáticos, transiciones auditadas, límite total y por cliente, descuento máximo, prioridad, lista objetivo y modo exclusivo o mejor precio. No se habilita acumulación ni cálculo de carrito sin una API compatible de redención múltiple.
- Simulador no mutante y advertencias de vigencias potencialmente coincidentes. La simulación no consume usos ni sustituye la verificación transaccional del límite.
- Evidencia prevista: `spec/models/commercial_lifecycle_spec.rb`, `spec/services/products/commercial_rules_spec.rb`, `spec/services/products/promotion_concurrency_spec.rb`, `spec/services/commercial/overlaps_spec.rb`, `spec/requests/admin/commercial_workflows_spec.rb` y las pruebas de navegador de campañas y simulador. Aceptación pendiente de CI del SHA integrado.

- Evidencia del SHA `8e87afa`: [Commercial CI](https://github.com/AliRodri1992/sales_point/actions/runs/45089004616), 168 pruebas funcionales y 21 de navegador, cero fallos; [Products CI](https://github.com/AliRodri1992/sales_point/actions/runs/45089004750) aprobado. En ese SHA queda una infracción de complejidad de RuboCop, corregida en la siguiente revisión. El dictamen integral exige comprobar CI en el SHA final y las demás puertas del estándar modular.

### Datos de demostración y paginación

- **PROMOTIONS-003 · P2 · PROPIO:** el listado utilizaba `table_pagination`, distinto del pie de catálogos. Se reutiliza `catalog_pagination` dentro del directorio, con Delta Select, enlaces y contador de página. La regresión de petición cubre dos páginas y conservación de filtros y orden. Verificación pendiente de CI del SHA publicado.
- Doce campañas demo con beneficios porcentuales y monetarios, condiciones sobre productos activos, vigencias, segmentos y límites. Sin redenciones simuladas ni sobrescritura de ediciones manuales.
- [Commercial CI #45091060738](https://github.com/AliRodri1992/sales_point/actions/runs/45091060738), SHA `76f0885`: 172 pruebas funcionales y 22 de navegador, cero fallos, incluida la navegación y el cambio de tamaño desde móvil. Pendiente CI del SHA de corrección de formato RuboCop.

### Adecuación visual Delta Emerald — 2026-11-22

- Alcance: directorio y sus indicadores organizacionales (estados efectivos, sin depender de la página), consulta, alta y edición. El nuevo SVG de porcentaje es compartido con el sidebar; no se modifica el icono de otros módulos.
- Mostrar, editar y eliminar aparecen de acuerdo con Pundit y el estado. Eliminar archiva con confirmación; conserva la campaña, sus redenciones y el historial. Los enlaces mantienen los parámetros del directorio.
- Secciones con ayuda contextual traducida, retícula equilibrada y simulador real de ancho completo. Delta Select se aplica también a enumeraciones y filas nuevas; el calendario personalizado mantiene el campo datetime-local original, la hora y los segundos.
- Evidencia prevista: `spec/requests/admin/commercial_workflows_spec.rb` y `spec/features/promotion_campaigns_browser_spec.rb`, más CI global. La auditoría estricta de I18n local pasó con 300 archivos y cero hallazgos de paridad. RSpec, RuboCop y Brakeman locales no ejecutados por ausencia de Docker. Estado del cambio: pendiente de verificación mediante CI y navegador.
- CI base `d6cc24ce`: [CI #45094723465](https://github.com/AliRodri1992/sales_point/actions/runs/45094723465) falla en `spec/features/admin_sidebar_navigation_spec.rb:25` (retorno del foco a `#sidebarToggle`). Es anterior a esta adecuación, que solo cambia la iconografía del sidebar; no cerrar ni atribuir automáticamente este fallo a Promociones.
- En el SHA de implementación `f6dcee317695683a43d8b8c3b467527ac03c96a3`, [Commercial CI #45096416346](https://github.com/AliRodri1992/sales_point/actions/runs/45096416346) aprobó 179 ejemplos funcionales y 31 de navegador, sin fallos. Security scans e I18n/YAML también pasaron en [CI #45096416272](https://github.com/AliRodri1992/sales_point/actions/runs/45096416272). RuboCop detectó una única ofensa `Rails/Pluck` en la prueba de permisos, corregida en el siguiente SHA; verificar CI de este último antes de cerrar.
