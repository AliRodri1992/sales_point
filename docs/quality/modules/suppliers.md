# Registro de calidad — Proveedores

**Estado:** INVENTARIADO, NO VERIFICADO, NO CERRADO.  
**Rutas propias:** `/admin/suppliers · /admin/suppliers/:id/contacts · /addresses · /bank_accounts · /products · /documents · /schedules · /events`
**Código de entrada confirmado/por comprobar al auditar:** `app/controllers/admin/suppliers_controller.rb; app/controllers/admin/supplier_contacts_controller.rb; app/controllers/admin/supplier_addresses_controller.rb; app/controllers/admin/supplier_bank_accounts_controller.rb`
**SHA de aceptación:** PENDIENTE · **Responsable/revisor:** por asignar · **Inicio de registro:** 2026-11-08

> Este documento establece el alcance y las puertas de aceptación; **no certifica que se haya realizado la auditoría**, que los archivos de pruebas existan o que CI esté verde. El registro se completa y versiona durante la auditoría del módulo.

## Alcance propio

Listado, expediente, nuevo/editar, fiscal/contactos/domicilios, bancos, catálogos de proveedor, documentos, calendarios, archivos, filtros, validaciones y permisos. Incluir subrecursos expresamente anidados en Proveedores.

Revisar únicamente las rutas y acciones declaradas y sus modelos, vistas, permisos, servicios, JS/CSS, locales es/en/ko y pruebas **directamente utilizados**. Inventariar métodos y rutas reales antes de probar; no presumir que cada operación CRUD existe.

## Límite de integración

Compras, cuentas por pagar y existencias: comprobar únicamente restricciones y enlaces propios del expediente del proveedor, sin auditar órdenes, movimientos o contabilidad.

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

No se han trasladado ni inventado hallazgos en esta apertura. **Esto no significa cero errores.** Al auditar, registrar IDs permanentes `SUPPLIERS-001` en adelante, prioridad P0–P3, clase PROPIO/INTEGRACIÓN/EXTERNO, evidencia (archivo/línea o reproducción), causa raíz, corrección, spec, SHA y estado; conservar los IDs en revisiones posteriores.

| ID | Prioridad | Clase | Evidencia/causa raíz | Prueba | Estado |
|---|---|---|---|---|---|
| — | — | — | Registro inicial; pendiente de auditoría | NO EJECUTADA | PENDIENTE |

## Verificaciones y dictamen

- **RSpec focalizado / completo:** NO EJECUTADO en este registro.
- **RuboCop / seguridad / I18n:** NO EJECUTADO en este registro.
- **Navegador real móvil y escritorio:** NO EJECUTADO en este registro.
- **GitHub Actions / SHA de aceptación:** NO CONFIRMADO.
- **P0/P1 conocidos y resueltos:** NO DETERMINADO.
- **Revisión independiente:** PENDIENTE.
- **Dictamen:** NO CERRADO. Al auditar, agregar comandos, fecha, resultados reales y enlaces de ejecución.

Política: [Estándar modular](../module-quality-standard.md) · [Plantilla ampliada](../module-audit-template.md).
