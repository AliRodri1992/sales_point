# Registro de calidad — Productos y catálogo

- **Módulo:** Productos — `/admin/products`, `/admin/products/:id/quote`, `/admin/product_images`.
- **Rama / SHA de inspección:** `feature/fixes` / `0481ca54046b633aa5b84667455fd134ba3139a4`.
- **Auditoría:** 2026-11-09; AI Dev Suite (impeccable-audit, ui-ux-pro-max, ponytail-engineering).
- **Estado:** **IMPLEMENTADO, PENDIENTE DE VERIFICACIÓN — cierre bloqueado por CI y pruebas de navegador**.
- **SHA de implementación más reciente:** `d4c575b3a323ab4ad6871c9c1d8d0fd6e96d8432`. **SHA de aceptación:** PENDIENTE. **Revisión independiente:** PENDIENTE.

## Alcance y responsabilidad

| Ruta / operación | Componentes examinados | Contrato externo |
|---|---|---|
| Listado / filtros / orden / paginación | `ProductsController`, `ProductsListing`, `ProductsLookup`, `_list`, `index`, specs requests | Totales de stock consultados por identificadores propios; Inventario es responsable de movimientos |
| Nueva / edición / eliminación lógica | `ProductsController`, `ProductFormWriting`, `SaveCatalogEntry`, `Product`, `ProductCommercialCatalog`, `_form`, `_commercial_row` | Referencias a Categorías, SAT, Proveedores e Inventario sin auditar flujos ajenos |
| Detalle e historial de precios | `_show`, `ProductPriceHistory`, `PriceChangeEvent`, `DecidePriceChange` | Listas de precios y promociones: únicamente interacción visible |
| Imágenes | `ProductImagesController`, `ProductImageAssignment`, `ImageUpload`, `ProductImageValidation`, controlador Uppy | Active Storage: archivos, firma, permisos y ciclo de vida |
| Cotización | `ProductPricingPreview`, `Products::Quote`, `product_quote_controller.js` | Listas y promociones: entradas, salida y errores |

**Fuera del alcance interno:** implementación completa de Categorías, SAT, Proveedores, Inventario, Ventas, Listas de precios, Promociones, Terminales y Onboarding. Cualquier fallo propio de esos módulos debe registrarse en su expediente.

## Hallazgos permanentes

Todos los hallazgos siguientes proceden de **inspección estática** del SHA indicado, excepto el estado de CI, obtenido de GitHub Actions. **No se ha reproducido ninguno en un navegador ni en RSpec durante esta auditoría.** Los riesgos de negocio se señalan como hipótesis cuando faltan escenarios ejecutados.

| ID | Prioridad / propiedad | Evidencia y naturaleza | Corrección y prueba de regresión requeridas | Estado |
|---|---|---|---|---|
| **PRODUCTS-001** | **P1 · PROPIO** | **Desacuerdo de unicidad insensible a mayúsculas.** `Product` valida `code` y `sku` con `case_sensitive: false`; `db/schema.rb` tiene índices únicos convencionales sobre `[organization_id, code]` y `[organization_id, sku]`, sin `lower(...)`. En escrituras simultáneas el índice no garantiza la regla del modelo. **Confirmado por código; concurrencia no reproducida.** | Añadir restricciones PostgreSQL consistentes con la regla, auditar duplicados y verificar escrituras concurrentes y datos legados por organización. | IMPLEMENTADO — NO VERIFICADO |
| **PRODUCTS-002** | **P1 · PROPIO** | **No existe flujo para retirar códigos secundarios obsoletos.** `_commercial_row.html.erb` muestra «Quitar» solo en filas no persistidas; `ProductFormWriting#product_params` no admite `_destroy`; los códigos secundarios no tienen selector de estado. Un código existente sigue utilizable si no se edita su valor. **Confirmado por código; efecto operacional por probar.** | Diseñar retiro lógico seguro de códigos secundarios, mantener el principal sincronizado, revisar referencias, botón/confirmación y specs de autorización, persistencia y reuso de identificador. | IMPLEMENTADO — NO VERIFICADO |
| **PRODUCTS-003** | **P2 · PROPIO** | **Errores de código de barras principal terminan fuera del campo.** `Product` valida unicidad de `barcode` pero no longitud/formato; `ProductCommercialCatalog#synchronize_primary_barcode` crea/actualiza `ProductBarcode`, que valida longitud y `Products::BarcodeFormat`; `SaveCatalogEntry` convierte errores de un registro hijo en `errors[:base]`. **Confirmado por código; probar entrada no imprimible y longitud mayor a 100.** | Validar explícitamente `barcode` en el modelo/servicio antes de guardar; adjuntar error a `barcode` y asegurar rollback. | IMPLEMENTADO — NO VERIFICADO |
| **PRODUCTS-004** | **P2 · PROPIO (helper compartido)** | **Errores de formulario sin asociación accesible y IDs duplicables.** `catalog_field` y `catalog_select` solo establecen `aria-invalid`; no agregan `aria-describedby` apuntando a `error_message_for`. El helper genera IDs basados en clase/atributo, por lo que dos variantes con error en `name` producen el mismo ID. **Confirmado por código; lector de pantalla no probado.** | Generar IDs por campo anidado, conectar el mensaje, conservar el formato «campo validación» y añadir specs para varios renglones inválidos y accesibilidad. | IMPLEMENTADO — NO VERIFICADO |
| **PRODUCTS-005** | **P2 · PROPIO / INTEGRACIÓN precios** | **Cotizador ofrece listas no necesariamente cotizables.** `_show` carga todas las `current_organization.price_lists.active`; `Quote#validate_price_list!` rechaza vigencias o segmentos incompatibles. La UI solo muestra un error genérico tras solicitar la cotización. **Confirmado por código; interacción no probada.** | Filtrar o describir listas según fecha/segmento y mostrar explicación localizada del rechazo, sin revelar datos de otras organizaciones. | IMPLEMENTADO — NO VERIFICADO |
| **PRODUCTS-006** | **P2 · PROPIO** | **Precio sin código de moneda en listado/detalle.** `_list` y `_show` llaman `number_to_currency(product.price)` sin el código de moneda base; `Products::Quote` y eventos sí contemplan la moneda organizacional. Puede confundirse el símbolo `$` entre MXN y USD. **Confirmado por código; impacto visual no probado.** | Mostrar el código de moneda organizacional junto con importes; probar organizaciones con MXN y USD y locale es/en/ko. | IMPLEMENTADO — NO VERIFICADO |
| **PRODUCTS-007** | **P2 · PROPIO** | **SKU del producto y de variantes no comparten restricción de unicidad.** `Product` verifica SKU entre productos; `ProductVariant` entre variantes; existen índices independientes. Un SKU igual puede quedar en ambos tipos de registro de la misma organización. **Confirmado por código; ambigüedad de escaneo es hipótesis.** | Definir formalmente la unicidad global por organización y, si aplica, introducir verificación transaccional/BD y specs de conflicto entre ambos tipos. | IMPLEMENTADO PARCIAL — concurrencia entre tablas no verificada |
| **PRODUCTS-008** | **P1 · INTEGRACIÓN Inventario (hipótesis)** | **Cambio de `tracking_mode` sin barrera explícita por inventario previo.** El formulario y params permiten cambiar `none/lot/serial`; `Product` solo valida enum, y `SaveCatalogEntry` no consulta lotes/series existentes. **Riesgo de coherencia por verificar** con contrato real de Inventario. | Probar producto con movimientos/lotes/series y definir transiciones permitidas en el límite de Productos. No refactorizar internamente Inventario aquí. | IMPLEMENTADO EN CÓDIGO — pendiente de prueba operativa |
| **PRODUCTS-009** | **P3 · DOCUMENTACIÓN** | **Guía funcional desactualizada.** `docs/modules/products.md` describe `stock`, `min_stock`, `max_stock` como atributos de `Product`, mientras `spec/models/product_spec.rb` verifica que el inventario no vive en esos campos. **Confirmado por comparación.** | Sincronizar la documentación con inventario por sucursal y las opciones comerciales actuales. | IMPLEMENTADO — NO VERIFICADO |

## Controles ya presentes: no duplicar hallazgos anteriores

- `ProductsLookup#accessible_products` limita catálogo y operaciones a la organización actual; `ProductImagesController` valida permisos y organización antes de aceptar imágenes.
- Uppy envía archivos localmente; `ImageUpload` verifica MIME real, tamaño y tokens por organización/usuario con vencimiento.
- `SaveCatalogEntry` registra cambios de precios y crea solicitudes de autorización para usuarios no administradores; la decisión usa bloqueos y revisa precio obsoleto.
- `Quote` valida cantidad, vigencia, opciones, precios y promociones; no equivale a flujo de cobro.
- El formulario de Productos usa `novalidate` y validaciones del modelo; el renderer del catálogo presenta errores individuales, salvo los casos de hallazgo 003/004.
- `spec/features/global_branded_selects_spec.rb` prueba que los selects de Productos se convierten en dropdowns Delta: **no** contabilizar el uso de `form.select` como incumplimiento por sí mismo.
- `ApplicationRecord` usa `acts_as_paranoid`; los modelos que heredan de él excluyen borrados lógicos por defecto. **No** registrar falsos positivos por referencias archivadas o unicidad con soft delete sin considerar este comportamiento.

## Evidencia de implementación (no equivale a aceptación)

Cambios publicados en `feature/fixes` sin fusionar:

| Área | Commits | Estado |
|---|---|---|
| Filtros avanzados compactos, estilos y specs | `dcf6dd6` | IMPLEMENTADO, pendiente de navegador/CI |
| Integridad de código principal/secundario, errores de campos, permisos de retiro y seguimiento | `9e87047`, `ce480cd`, `9c8f18e` | IMPLEMENTADO, pendiente de RSpec/CI |
| Cotización con listas vigentes y mensajes específicos | `b33feb0` | IMPLEMENTADO, pendiente de RSpec y navegador |
| Restricciones de unicidad e integridad de schema | `542e369` | MIGRACIÓN PUBLICADA, pendiente de ejecución |
| Regresiones en modelos y solicitudes | `5bbbca1`, `3c9599f` | PRUEBAS ESCRITAS, ejecución pendiente |
| Guía de Producto actualizada | SHA de este registro | DOCUMENTADO |

**Riesgo no cerrado:** `PRODUCTS-007` tiene validaciones cruzadas de SKU por modelo, pero una concurrencia real entre las tablas Productos y Variantes todavía requiere garantía transaccional o decisión documentada del propietario. Mantener abierto hasta resolverlo.

**Revisión visual pendiente:** filtros avanzados, botón compacto, móvil 320/390/768 px, foco/teclado, selector de precio, errores repetidos y zoom 200%.

## Estado de GitHub Actions del SHA auditado

Fuente: [CI #42615013668](https://github.com/AliRodri1992/sales_point/actions/runs/42615013668), SHA `0481ca5`.

| Trabajo | Resultado real | Atribución |
|---|---|---|
| Fresh migrations and seed data | **PASÓ** | Control transversal; no acredita todos los casos de Productos |
| Security scans | **PASÓ** | Control transversal |
| Rails I18n and YAML audit | **PASÓ** | Control transversal |
| RSpec / Guard against N+1 query regressions | **FALLÓ** | El caso específico Productos y su escalado de consultas pasó con conteos `{1=>1,20=>1,100=>1}`; falló `spec/requests/admin/clients_spec.rb:32` por respuesta 403. **EXTERNO: Clientes** |
| RuboCop | **FALLÓ** | 1146 archivos, 28 infracciones; en el reporte no se listaron archivos propios de Productos. Entre los errores hay archivos de Inventario, Compras, Onboarding y utilidades transversales. **Bloqueo transversal, no defecto de Productos** |

**Pruebas focalizadas en esta auditoría:** NO EJECUTADAS por ausencia de un entorno Rails/Docker conectado. La consulta de logs históricos del SHA no sustituye su ejecución ni confirma que toda la suite Productos esté verde.

**Pruebas de navegador (320/390/768/1440 px, zoom 200 %, foco, teclado, errores, scroll):** NO EJECUTADAS EN ESTA AUDITORÍA.

**Matriz de regresión recomendada:**

- `spec/requests/admin/products_spec.rb`, `spec/requests/admin/product_tenant_access_spec.rb`;
- `spec/models/product_spec.rb`, `spec/features/catalog_redesign_browser_spec.rb`, `spec/features/global_branded_selects_spec.rb`;
- `spec/services/products/price_authorization_spec.rb`, `spec/services/products/commercial_integrity_spec.rb`, `spec/services/products/commercial_pricing_spec.rb`, `spec/services/products/image_security_spec.rb`;
- nuevas regresiones para `PRODUCTS-001` a `PRODUCTS-008` y validación de formularios/navegación accesible.

## Traspasos y reglas de cierre

- **Inventario:** verificar únicamente que el cambio de `tracking_mode` desde Productos no invalida existencias, lotes ni números de serie; registrar internals en `docs/quality/modules/inventory.md` si hay un defecto ajeno.
- **Listas/Promociones:** verificar únicamente lista ofrecida → respuesta de cotización → mensaje de error en Productos.
- **Categorías/SAT/Proveedores:** validar referencias seleccionables/archivadas y feedback desde el formulario de Productos; no extender la auditoría al CRUD vecino.
- **CI global:** requiere corregir bloqueos transversales en los módulos propietarios, sin imputarlos a Productos.

## Dictamen

**IMPLEMENTADO EN CÓDIGO; VERIFICACIÓN PENDIENTE; NO CERRADO.**

Hay **2 hallazgos P1 propios basados en el código**, **1 riesgo P1 de integración pendiente de reproducción**, **5 P2** y **1 P3**. Los estados no acreditan fallas observadas en un entorno de ejecución.

Puertas restantes: corregir P1 y P2 o aceptar riesgos según el estándar, añadir regresiones, ejecutar RSpec/RuboCop/security/I18n y revisión de navegador real, comprobar **GitHub Actions verde en el SHA de aceptación** y obtener revisión independiente. No fusionar ramas en estado rojo.

Política: [Estándar modular](../module-quality-standard.md) · [Plantilla](../module-audit-template.md).
