# Registro de calidad — Productos y catálogo

- **Módulo:** Productos — `/admin/products`, `/admin/products/:id/quote`, `/admin/product_images`.
- **Rama / SHA de inspección original:** `feature/fixes` / `0481ca54046b633aa5b84667455fd134ba3139a4`. **Reauditoría integral de código:** `feature/fixes` / `4a39eef1c00099c7cc0e48042255571e133d5516`.
- **Auditoría:** 2026-11-09; AI Dev Suite (impeccable-audit, ui-ux-pro-max, ponytail-engineering).
- **Estado:** **IMPLEMENTADO, PENDIENTE DE VERIFICACIÓN — cierre bloqueado por CI y pruebas de navegador**.
- **Rediseño y endurecimiento recientes:** `8bf0d5b`, `f40bf16`; corrección RuboCop registrada en este cambio. **SHA de aceptación:** PENDIENTE. **Revisión independiente:** PENDIENTE.

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

## Reauditoría focalizada — filtros avanzados (2026-11-09)

**Código base inspeccionado:** `4d2eaf3` en `feature/fixes`. Método de AI Dev Suite: revisión de UX con `impeccable-audit` + criterios de `ui-ux-pro-max` y cambio acotado de `ponytail-engineering`. La identificación de fallos procede de comparación de rutas, Turbo, formularios y componentes; **no** de una sesión visual ejecutada.

| ID | Prioridad / propiedad | Hallazgo y causa comprobable | Remediación publicada | Estado |
|---|---|---|---|---|
| **PRODUCTS-010** | **P1 · PROPIO** | El formulario GET dirigía la actualización exclusivamente a `admin_products_list`, mientras sus filtros quedaban fuera del frame. Los enlaces de orden/paginación también navegaban el frame, dejando `window.location` atrás. `table_page_size_controller.js` usa esa URL visible, por lo que una preferencia nueva perdía parámetros filtrados. | `_filters` usa navegación `_top`, y `_list` hace lo propio con orden/páginas, manteniendo URL, recarga, tamaño de página e historial coherentes. | **CORREGIDO EN CÓDIGO — NO VERIFICADO EN NAVEGADOR** |
| **PRODUCTS-011** | **P2 · PROPIO** | No había chips que identificaran criterios activos ni enlaces para quitar un criterio concreto, pese al estándar modular. Panel de seis campos y botón con tratamiento visual inconsistente frente a Clientes/Sucursales. | Panel reorganizado, dropdowns Delta, categoría con búsqueda, contador de filtros avanzados, chips removibles, limpieza total y botón `Aplicar filtros` compacto (sin ancho completo en móvil). | **CORREGIDO EN CÓDIGO — NO VERIFICADO EN NAVEGADOR** |
| **PRODUCTS-012** | **P2 · PROPIO** | Ya existía `products_search_controller.js` con búsqueda diferida, pero `index.html.erb` no lo conectaba: la búsqueda dependía de pulsar Aplicar. | Se conecta Stimulus al formulario y la entrada de búsqueda, con debounce de 400 ms y protección durante composición IME; la búsqueda incremental actualiza solo el listado y los chips con una respuesta HTML del servidor, sincroniza la URL y mantiene el foco. El botón Aplicar sigue disponible como ruta de recuperación. | **CORREGIDO EN CÓDIGO — NO VERIFICADO EN NAVEGADOR** |

**Evidencia de cambios:** `443b960` (navegación, controles, chips), `5b36ff0` (responsive y `es/en/ko`), `3a70339` (RSpec request y flujo navegador). Las pruebas están escritas, pero no se declara su aprobación hasta obtener resultados efectivos en el SHA de aceptación.

**Criterios adicionales de aceptación:** búsqueda → URL persistida; estado/categoría/destacado/seguimiento/existencias/precios combinados; selección de categorías tenant-safe; chip individual sin perder los otros; botón que nunca ocupa todo el ancho; cambio de página, orden y tamaño sin borrar el filtrado; uso por teclado/lector y en anchos de 320/390/768/1440 px. Se requiere CI focalizado y ejecución visual real.

## Segunda inspección de filtros y listado — 2026-11-09

- **PRODUCTS-013 (P1 · filtros):** la navegación GET normal y el buscador incremental descartaban `sort`, `direction` y `per_page` al construir parámetros, aunque la paginación y el selector de tamaño preservaban la URL. Se añaden campos ocultos validados contra listas permitidas y se prueba su conservación en el formulario y el flujo navegador.
- **PRODUCTS-014 (P2 · UX/estabilidad):** el buscador incremental sustituía el elemento `turbo-frame` completo por otro creado mediante `DOMParser`. Esto interrumpe el ciclo de vida del frame; ahora conserva el nodo y reemplaza solo sus hijos, evitando perder el foco del buscador o el estado del wrapper.
- **PRODUCTS-015 (P2 · presentación):** la página local de Productos en español mostraba un importe con el símbolo **€** acompañado del código **MXN**. `product_money` dependía del símbolo predeterminado del locale; ahora escoge el símbolo explícito para MXN, USD, EUR y KRW sin quitar el código ISO.
- **PRODUCTS-016 (P2 · robustez):** `_filters` llamaba directamente a `current_organization.categories` sin proteger el caso de organización no resuelta, mientras `ProductsLookup` ya contempla ese caso. El selector pasa a devolver opciones vacías sin excepción.
- **PRODUCTS-017 (P3 · comportamiento):** el texto de búsqueda literal `all` se descartaba como si fuera un valor comodín de dropdown; la normalización se limita a los selectores con opción `all` y se elimina el `name=button` innecesario de la petición GET.

**Implementación y verificación:** los cambios de esta reauditoría están publicados en `feature/fixes`, con pruebas de solicitud y de navegador escritas. **No se ha ejecutado una prueba interactiva del localhost**: la conexión de navegador en modo Chat permite inspeccionar el contenido de la pestaña abierta, pero no enviar clics ni introducir valores. El cierre sigue condicionado a RSpec/CI y a una verificación interactiva real tras actualizar el entorno local.

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

## Auditoría integral de Productos y adecuaciones — 2026-11-09 (revisión de código)

**Método:** AI Dev Suite, `impeccable-audit` (pantallas y estados), `ui-ux-pro-max` (diseño y accesibilidad), `ponytail-engineering` (integridad, cambios acotados y regresión). **Revisión estática** de las rutas de Productos y sus contratos visibles. El acceso a una pestaña `localhost:3000/admin/products` permitió leer contenido, pero **no ejecutar clics ni pruebas visuales de navegador**; no se certifica la apariencia final.

### Cobertura comprobada de código

| Flujo | Revisión y evidencia | Riesgo / límite |
|---|---|---|
| Listado, filtros, orden, paginación | `index`, `_filters`, `_list`, `ProductsListing`, `ProductsLookup`, Stimulus, `spec/requests/admin/products_spec.rb` y `spec/controllers/concerns/admin/products_listing_spec.rb` | Rediseño por grupos y acciones compactas; interacciones móviles/zoom no verificadas |
| Crear, actualizar y cancelar | `ProductsController`, `ProductFormWriting`, `SaveCatalogEntry`, `_form`, `Product` y validaciones por campo | Validar visualmente errores 422 anidados, reintentos e historial de precio |
| Variantes, presentaciones y códigos de barras | `ProductCommercialCatalog`, `ProductVariant`, `ProductPresentation`, `ProductBarcode`, `_commercial_row` y `nested_catalog_controller.js` | Unicidad entre tablas de SKU (`PRODUCTS-007`) permanece abierta a concurrencia |
| Detalle, historial y cotización | `_show`, `ProductPriceHistory`, `ProductPricingPreview`, `Products::Quote`, `DecidePriceChange`, `product_quote_controller.js` | Validar en ejecución errores JSON 404, segmentos, listas y movimientos de precios |
| Imágenes | `ProductImagesController`, `ProductImageAssignment`, `ProductImageValidation`, `ImageUpload`, `product_upload_controller.js` | Token con propósito por usuario/organización, MIME real y límite 5 MB presentes en código; completar pruebas funcionales |
| Bajas y permisos | `ProductPolicy`/`CatalogPolicy`, `ProductsController#destroy`, borrado lógico, `granular_catalog_permissions_spec.rb`, `product_tenant_access_spec.rb` | Verificar respuestas 401/403/404 y dependencias con Inventario/Compras; no cambiar políticas de módulos vecinos |
| Traducciones/UX | `catalog_workspace.css`, parciales de listado/detalle/formulario y `catalog_design.{es,en,ko}.yml` | Traducciones de grupos añadidas; zoom 200 % y navegación teclado requieren navegador |

### Seguimiento incremental: IDs permanentes

| ID | Prioridad y ámbito | Evidencia precisa (inspección estática, salvo CI señalado) | Remediación / prueba | Estado |
|---|---|---|---|---|
| **PRODUCTS-018** | **P2 · Productos / UX** | `_filters.html.erb` distribuía categoría, destacado, modalidad de seguimiento, stock y precios en una grilla plana; las acciones estaban al pie del desplegable, desconectadas de búsqueda/estado. | Grupos semánticos **Clasificación**, **Inventario** y **Rango de precios**, con `fieldset`/`legend`, barra principal alineada, búsqueda con lupa y botón Aplicar compacto. Traducciones `es/en/ko`. Requests y navegador móvil añadidos en `8bf0d5b`. | IMPLEMENTADO; NO VERIFICADO EN NAVEGADOR |
| **PRODUCTS-019** | **P2 · Productos / respuesta API** | `ProductPricingPreview#quote_option` usa `scope.find` y `ProductsController` redirige por `RecordNotFound`, incluso si la solicitud de cotización AJAX esperaba JSON. | Se devuelve 404 JSON localizado para opción no accesible. Regresión de variante de otra organización. `f40bf16`. | IMPLEMENTADO; RSpec PENDIENTE |
| **PRODUCTS-020** | **P2 · Productos / presentación y consultas** | `_show` formateaba eventos con `number_to_currency` predeterminado del locale y podía mostrar símbolo ajeno a la divisa del evento; `_list` no incluía explícitamente la organización al sumar existencias, aunque consultaba IDs filtrados. | Historial usa `product_money(..., currency: event.currency)` y total del listado se acota por `organization_id`. `f40bf16`. | IMPLEMENTADO; RSpec PENDIENTE |
| **PRODUCTS-021** | **P2 · Productos / rendimiento y entradas** | `ProductsListing#apply_search_filter` solo dependía de `maxlength=100` en HTML; el servidor aceptaba búsquedas de longitud ilimitada por GET, amplificando filtros `ILIKE`. | Límite server-side a 100 caracteres y prueba de query en `products_listing_spec.rb`. `f40bf16`. | IMPLEMENTADO; RSpec PENDIENTE |
| **PRODUCTS-022** | **P1 · Productos / CI** | En [CI #42764751462](https://github.com/AliRodri1992/sales_point/actions/runs/42764751462), RuboCop reportó `Rails/Pluck` en `spec/requests/admin/products_spec.rb:420`; **1 infracción de 1165 archivos**, causada por `chips.map { ... }`. | Sustituido por `chips.pluck('aria-label')` en esta adecuación. No afirmar éxito hasta la siguiente ejecución en el SHA publicado. | IMPLEMENTADO; CI PENDIENTE |

**No se duplican hallazgos** `PRODUCTS-001`–`PRODUCTS-017`; se mantienen sus IDs, causas y estados. En particular `PRODUCTS-007` sigue abierto a escritura concurrente entre tablas, a pesar de las validaciones cruzadas e índices independientes. El manejo de inventario histórico del `PRODUCTS-008` requiere regresión con movimientos, lotes y números de serie.

### Evidencias efectivas de CI y puertas pendientes

- [CI #42762512143](https://github.com/AliRodri1992/sales_point/actions/runs/42762512143) sobre `1276798`: **migraciones, Seguridad e I18n PASARON**; **RSpec falló** en escalamiento de teléfonos de Clientes (`spec/performance/n_plus_one_scaling_spec.rb:51`, ámbito **externo a Productos**); **RuboCop falló** por una infracción de `products_spec.rb` (propia; corregida aquí).
- [CI #42764751462](https://github.com/AliRodri1992/sales_point/actions/runs/42764751462) sobre `f40bf16`: Seguridad e I18n **PASARON**; RuboCop **FALLÓ** por la misma infracción. Las demás etapas no tenían resultado final completo en la última consulta.
- Los specs escritos **no son evidencia de ejecución aprobada**; la revisión móvil **no** se ha ejecutado. No se han alterado datos ni ejecutado comandos Rails/Docker sobre el equipo del usuario.
- Puertas de aceptación restantes: RSpec del módulo y completo, RuboCop, migraciones, Seguridad, traducciones, navegador (320/390/768/1440 px, zoom 200 %, teclado, dropdowns y botón), concurrencia SKU, y revisión independiente del expediente en el mismo SHA.

**Dictamen de esta reauditoría integral:** cambios publicados, alcance inspeccionado y riesgos trazados; **VERIFICACIÓN PENDIENTE / NO CERRADO**.

## Auditoría de código completa — 2026-11-10 (SHA `f9e5f648b3b4c8f658780bff9bb3b3c5b3a61dc6`)

**Alcance:** reauditoría sobre el estado real de `feature/fixes`, sin reiniciar los hallazgos `PRODUCTS-001` a `PRODUCTS-022`. Método AI Dev Suite: `impeccable-audit` para estados y accesibilidad, `ui-ux-pro-max` para formularios/listado/responsive, `ponytail-engineering` para dominio, seguridad, permisos y rendimiento. La suite se usó como **metodología de inspección**; no se ejecutaron CLIs de terceros. El análisis se hizo con código de GitHub y logs de GitHub Actions, no con Rails/Docker ni con pruebas interactivas del localhost.

### Matriz de alcance integral y resultado

| Pantalla/flujo propio | Componentes examinados | Dictamen sustentado |
|---|---|---|
| Listado, búsqueda, filtros activos, orden y paginación | `index`, `_filters`, `_list`, `ProductsListing`, `ProductsLookup`, `products_search_controller.js`, CSS y request/feature specs | Implementada la disposición compacta y grupos semánticos, autocompletado/búsqueda diferida, enlaces y persistencia de parámetros; **sin interacción visual probada** |
| Alta y edición | `_panel`, `_form`, `ProductsController`, `ProductFormWriting`, `SaveCatalogEntry`, validaciones del modelo, helper de errores | Validaciones por campo y bloqueo de cambio de precio sin justificación; permanecen casos negativos de referencia y anidamiento pendientes |
| Identidad comercial | `Product`, `ProductVariant`, `ProductPresentation`, `ProductBarcode`, `ProductCommercialCatalog`, `_commercial_row`, `nested_catalog_controller.js` | Índices case-insensitive implementados **por tabla**, baja lógica de códigos secundarios, referencias por organización; pendiente aislamiento de SKU en concurrencia cruzada |
| Ver producto y precios | `_show`, `ProductPriceHistory`, `PriceChangeEvent`, `DecidePriceChange`, UI del cotizador | Historial de moneda, permisos y bloqueo de aprobación obsoleta; sin probar navegación de historial, selectores y errores con teclado |
| Cotización | `ProductPricingPreview`, `Products::Quote`, `product_quote_controller.js` | Validaciones de cantidad, lista, vigencia, segmento, organización, variantes y moneda; respuesta JSON 404 para referencias ausentes; falta prueba de navegador |
| Imágenes | `ProductImagesController`, `ProductImageAssignment`, `ImageUpload`, `ProductImageValidation`, Uppy y specs | Comprueba permisos, MIME real, 5 MB, firma con propósito/usuario/organización y expiración; falta prueba visual subida/error/reintento |
| Permisos, eliminación y notificaciones | `ProductPolicy`, `CatalogPolicy`, `ProductsController#destroy`, `CatalogNavigation`, specs de permisos y acceso entre organizaciones | Defensa por acción Pundit, scoping por tenant y retiro lógico con bloqueo de historial; resultados 401/403/404/422 pendientes de ejercicio integral |
| Rendimiento/idiomas | `_list`, `ProductsListing`, CSS, `catalog_design.{es,en,ko}.yml`, pruebas N+1 | La prueba de N+1 de Productos en CI registró 1 consulta de totales para 1/20/100 productos; i18n y lint pasan en el SHA auditado |

### Hallazgos nuevos — conservar estos IDs

| ID y prioridad | Propiedad / evidencia de código | Impacto, reproducción mínima y prueba solicitada | Estado |
|---|---|---|---|
| **PRODUCTS-023 · P1** | **PROPIO / confirmado por lógica de resolución.** `ProductsLookup#find_product_by_id_or_slug` prioriza `find_by(slug: id_param)`; si no hay coincidencia exacta, `find_product_by_code` mezcla `lower(slug)` y `lower(code)` mediante `OR` y toma `.first`. Los índices únicos son independientes para código y slug, así que un código puede coincidir con el slug de otro producto en la misma organización. | Producto A con `code: 'coffee'`, `slug: 'product-a'`; producto B con `slug: 'coffee'`, `code: 'product-b'`: solicitar `/admin/products/coffee` abre B, no A. **La ruta por código es ambigua**; existe riesgo de operar el registro equivocado si se utiliza ese identificador en la URL. Separar semánticamente rutas por código/slug o establecer precedencia inequívoca y probar lectura/edición y variantes de mayúsculas. | **ABIERTO — confirmación de escenario por RSpec pendiente** |
| **PRODUCTS-024 · P2** | **PROPIO / discrepancia de reglas por confirmar.** `_form` usa `current_organization.categories.available`, pero `Product#valid_catalog_references` valida presencia y pertenencia para `category_id`, **no que la categoría esté activa**; también admite `organization_id: nil` en una categoría. | Un POST manipulado podría asignar una categoría inactiva no seleccionable en el formulario. Confirmar si las categorías globales y las inactivas son legadas válidas o si solo deben retenerse al editar **sin permitir asignaciones nuevas**. Añadir pruebas para alta, cambio y conservación histórica en cada caso. | **HIPÓTESIS DE REGLA — aclarar negocio antes de corregir** |
| **PRODUCTS-025 · P2** | **PROPIO / confirmado en formulario.** `_commercial_row` genera los selectores de `product_variant_id` y `product_presentation_id` con `@product.*.select(&:persisted?)`. Las variantes y presentaciones recién agregadas en ese formulario no están persistidas. | En un alta que agrega variante nueva y código secundario, el código **no puede asociarse a la variante recién creada** en el mismo formulario; requiere un guardado y una edición posteriores. Definir si se acepta flujo de dos etapas y explicarlo en UX, o soportar referencias temporales y resolverlas transaccionalmente. Probar el escenario con JS y request. | **ABIERTO — decisión UX/flujo pendiente** |
| **PRODUCTS-026 · P2** | **PROPIO / confirmado por código.** `ProductsListing#apply_price_filter` aplica mínimo y máximo por separado; `_filters` no valida la relación entre ellos ni muestra un error debajo del par. | Solicitar `min_price=200&max_price=100` produce un resultado vacío sin indicar el rango inválido. Implementar validación de cruce en servidor, mensaje localizado en el grupo de precios y control accesible del error; prueba GET y pantalla a 390 px. | **ABIERTO — remediación pendiente** |

**No duplicar causas antiguas:** `PRODUCTS-001` ya tiene índices `LOWER(code)` y `LOWER(sku)` en `db/schema.rb` y migraciones. `PRODUCTS-002` tiene `_destroy` para códigos secundarios; `PRODUCTS-003/004` cuentan con validación del código principal y `aria-describedby` por campo; `PRODUCTS-008` verifica inventarios históricos, movimientos y lotes antes de modificar `tracking_mode`. **PRODUCTS-007 permanece abierto**: la validación cruzada entre `products` y `product_variants` no impide por sí sola escrituras simultáneas en tablas distintas; debe protegerse con una estrategia transaccional demostrable y tests concurrentes.

### Resultado real de controles y atribución

**SHA del código auditado y del CI:** `9ac9c227f729bbcc8b045ee8604775d083e41511` · [CI #42809388942](https://github.com/AliRodri1992/sales_point/actions/runs/42809388942). El SHA inicial de esta sección (`f9e5f64`) únicamente añadió documentación al expediente de Categorías; los archivos inspeccionados de Productos no cambiaron entre ambos SHA.

| Control | Resultado confirmado | Propiedad |
|---|---|---|
| RuboCop | **PASÓ** | Global |
| Security scans | **PASÓ** | Global |
| Rails I18n and YAML audit | **PASÓ** | Global |
| Fresh migrations and seed data | **PASÓ** | Global; no equivale a prueba concurrente |
| RSpec, guardia de N+1 | **FALLÓ** | **EXTERNO: Clientes**. `spec/performance/n_plus_one_scaling_spec.rb:51` esperaba al menos una consulta SQL de teléfonos y obtuvo 0. La prueba de Productos en el mismo job mostró **{1=>1, 20=>1, 100=>1}** para agregaciones de existencias, sin crecimiento de N+1 |

El fallo de Clientes **bloquea la aceptación global**, pero no se atribuye a Productos. El RSpec general no es verde y las suites focalizadas de formularios, cotizaciones, concurrencia y navegador **no se han ejecutado en este trabajo**. Las pruebas existentes se inspeccionaron, sin atribuirles aprobación que no consta en los logs.

### Plan de verificación priorizado, sin aprobar anticipadamente

1. **P1 — Identidad y unicidad:** reproducir `PRODUCTS-023` con código/slug homónimos, resolver precedencia, ejecutar RSpec de lectura/edición; proteger `PRODUCTS-007` entre tablas en concurrencia con transacciones paralelas.
2. **P2 — Alta y edición:** verificar anidamiento de variantes/presentaciones/códigos (`PRODUCTS-025`), catálogos activos e históricos (`PRODUCTS-024`), rollback al fallar nested records, precio con motivo, registro y aprobación concurrente.
3. **P2 — Listado/UI:** probar precios invertidos (`PRODUCTS-026`), combinación de 8 criterios, chips, historial, ordenación, paginación, cambio de tamaño, carga/vacío/error, dropdowns, teclado, foco, lector y zoom 200 %; resoluciones 320/390/768/1440 px.
4. **Seguridad:** verificar 401/403/404/422, protección entre organizaciones, URLs por slug y código, rechazo de archivos falsificados/expirados, tokens de imagen y redirecciones seguras.
5. **CI:** finalizar RSpec focalizado y global, RuboCop, I18n, migraciones y seguridad para **el mismo SHA de aceptación**, más revisión independiente.

**Estado y decisión:** `AUDITADO — NO CERRADO`. Esta reauditoría **no modificó lógica, esquema ni datos**; agrega evidencia y nuevos hallazgos al registro permanente. Faltan pruebas interactivas de navegador real: la única pestaña local accesible en modo de lectura estaba en `/admin/languages`, no en Productos. Ningún resultado de UX/zoom se presenta como observado.

## Adecuaciones de hallazgos abiertos — 2026-11-10

**Rama:** `feature/fixes`. Los cambios siguientes se implementaron tras la auditoría anterior y conservan los IDs originales; **implementado no equivale a verificado**.

| Hallazgo | Adecuación efectuada | Evidencia / estado |
|---|---|---|
| **PRODUCTS-007 (P1)** | Nuevo registro `product_sku_claims`, índice único por organización y SKU normalizado y callbacks transaccionales en `Product` y `ProductVariant`; migración con revisión de conflictos legados y backfill. Las escrituras a través de los modelos compiten por la misma reserva. | `20261110160000_create_product_sku_claims.rb`, concern `ProductSkuReservation`, `product_sku_claim_spec.rb` incluye prueba concurrente. **IMPLEMENTADO, PENDIENTE DE RSpec/DB**. Los cambios por SQL directo que omitan callbacks requieren seguir el contrato de reservas. |
| **PRODUCTS-023 (P1)** | Las URLs generadas utilizan ID numérico estable; resolución por slug/código solo devuelve un resultado si hay una coincidencia única. El modelo rechaza nuevos conflictos cruzados de código y slug y evita generar slugs que colisionen con códigos existentes. | `Product`, `ProductsLookup`, specs de modelo, búsqueda y request; casos legados construidos saltando validación deliberadamente. **IMPLEMENTADO, PENDIENTE DE RSpec**. |
| **PRODUCTS-024 (P2)** | Se rechazan nuevas asignaciones a categorías inactivas, eliminadas y ajenas. Se conserva una categoría histórica inactiva si el campo no cambia. Los datos de demostración seleccionan solamente categorías activas. | `Product#valid_catalog_references`, `db/seeds.rb`, spec del modelo. **IMPLEMENTADO, PENDIENTE DE RSpec/SEEDS**. |
| **PRODUCTS-025 (P2)** | El editor permite seleccionar variantes y presentaciones creadas en el mismo formulario antes del primer guardado. Claves temporales enlazadas con registros anidados dentro de la validación; el servidor rechaza tokens sin coincidencia. | `_commercial_row`, `nested_catalog_controller.js`, `ProductFormWriting`, `ProductCommercialCatalog`, specs request y feature. **IMPLEMENTADO, PENDIENTE DE RSpec/NAVEGADOR**. |
| **PRODUCTS-026 (P2)** | Un mínimo mayor que el máximo ya no elimina todos los resultados sin explicación: aparece un error localizado asociado por ARIA a ambos campos y el listado conserva los demás criterios. La búsqueda dinámica sincroniza el error. | `Products::PriceFilter`, `ProductsListing`, `_filters`, JS, CSS, locales `es/en/ko` y request spec. **IMPLEMENTADO, PENDIENTE DE RSpec/NAVEGADOR**. |

**Hallazgo de CI secundario:** un primer CI tras estas adecuaciones indicó 17 ofensas RuboCop y que Brakeman no podía analizar la expresión de ARIA de precios. Se refactorizaron los métodos señalados y se simplificó el ERB en un commit posterior. El mismo primer CI no llegó a ejecutar la suite de RSpec porque las semillas asignaban categorías inactivas a productos; se ajustó `db/seeds.rb`. Revalidar **en el commit final**.

**Aún pendientes para aceptación:** ejecución completa de RSpec, migraciones y seeds sin errores, Brakeman, RuboCop y traducciones en el SHA publicado; navegador real (formulario anidado, filtros, teclado, resoluciones 320/390/768/1440, zoom 200 %); revisión independiente. No se aplicó ningún cambio a la base de datos de desarrollo del usuario desde esta sesión.

## Verificación focalizada de Productos — 2026-11-10

La primera ejecución real de [Products CI #42817098840](https://github.com/AliRodri1992/sales_point/actions/runs/42817098840) inspeccionó 195 ejemplos de modelos, transacciones, controladores, servicios e integración. **190 aprobaron y 5 fallaron**: dos expectativas incorrectas del atributo HTML booleano `details[open]`, una selección de campos que incluía el contenido de un `template` de filas vacías, una moneda de prueba no creada y una categoría de otra organización usada por el spec de promociones. Las pruebas de reserva compartida de SKU, incluida la concurrencia entre dos inserciones, **pasaron**. La ejecución no llegó al paso de navegador porque los ejemplos anteriores fallaron.

Se actualizaron las expectativas sin alterar el comportamiento correcto de producción: revisión de presencia real del atributo `open`, selector limitado a filas activas, creación explícita de MXN y uso de categoría perteneciente a la organización del producto. Se incorporó también el test de paginación al CI de Productos: su expectativa `admin_products_list` estaba obsoleta desde que los enlaces usan `_top` para mantener los filtros en la URL.

**Estado:** correcciones de regresión publicadas; aceptación condicionada a repetir el CI focalizado completo, incluidas las pruebas de navegador en esta misma rama.

## PRODUCTS-027 — Selección de opciones nuevas en navegador (2026-11-10)

**P1 · Interfaz de alta / impacto real demostrado.** [Products CI #42818044846](https://github.com/AliRodri1992/sales_point/actions/runs/42818044846) pasó modelos, requests, SQL, concurrencia y paginación, pero **falló** una prueba real de navegador: al guardar un código de barras para una variante nueva, el código se persistió **sin** `product_variant_id`. [Products CI #42818823533](https://github.com/AliRodri1992/sales_point/actions/runs/42818823533) aisló la causa: inmediatamente antes del envío el `select` nativo contenía `value=""` aunque la opción `new:1794315018704` estaba disponible y el `client_key` existía en el formulario. `nested_catalog_controller.js#refreshLinks` destruía y recreaba todos los `option` dinámicos ante **cada evento input**, invalidando la selección del navegador.

**Corrección:** actualizar las opciones de forma incremental (crear nuevas, actualizar etiquetas y retirar únicamente las desaparecidas) sin desmontar la opción seleccionada; recuperar el valor temporal únicamente al restaurar errores del formulario. La prueba de navegador `spec/features/products_quality_browser_spec.rb` ahora exige selección real y persistencia de las asociaciones tras modificar otro campo.

**Estado:** CORREGIDO EN CÓDIGO; verificar en CI y navegador antes de marcar CERRADO. No hay modificaciones de datos locales.


## Adecuaciones adicionales de la revisión completa — 2026-11-11

| Hallazgo | Corrección adicional | Verificación |
|---|---|---|
| **PRODUCTS-002** | El retiro de un código secundario ahora asigna `deleted_at` dentro del guardado del producto; la asociación y las búsquedas solo incluyen códigos activos, el índice parcial y la validación liberan el valor retirado para reutilización. El código principal se mantiene protegido contra retiro anidado. | Requests añadidos para conservar historial, reutilizar el valor y bloquear el retiro del principal. **Pendiente de CI**. |
| **PRODUCTS-027** | La regresión de navegador ahora selecciona las variantes/presentaciones mediante el dropdown visual Delta, no manipulando directamente el `select` nativo oculto. | **Products CI #43014643648 PASÓ** (RuboCop y dos flujos de navegador); incluye el cambio de prueba del dropdown real. |
| **PRODUCTS-019** | La expectativa de opción comercial ajena se ajustó al contrato de seguridad existente: 404 JSON localizado, sin redirección HTML. | Request spec actualizado; pendiente de CI actual. |

**CI actual tras el retiro lógico:** Products CI #43015071259 detectó una única infracción de formato RuboCop en `product_barcode.rb`; se corrigió en el commit siguiente. La suite focalizada estaba ejecutándose al actualizar este registro. El CI general previo #42821578997 registró 133 fallos globales; los fallos de Productos identificados fueron la selección de opción nueva y expectativas de sincronización URL en specs de navegador. El resto pertenece a otros módulos y no se atribuye a Productos.

**No cerrar aún:** PRODUCTS-001–027 permanecen sujetos a los controles del mismo SHA final, en particular la prueba completa de códigos retirados, concurrencia SKU, cotizador, tracking con inventario existente, filtros y navegación real. Los hallazgos ya implementados no se marcan como verificados solo por tener código o specs añadidos.

## Dictamen

**IMPLEMENTADO EN CÓDIGO; VERIFICACIÓN PENDIENTE; NO CERRADO.**

Hay **2 hallazgos P1 propios basados en el código**, **1 riesgo P1 de integración pendiente de reproducción**, **5 P2** y **1 P3**. Los estados no acreditan fallas observadas en un entorno de ejecución.

Puertas restantes: corregir P1 y P2 o aceptar riesgos según el estándar, añadir regresiones, ejecutar RSpec/RuboCop/security/I18n y revisión de navegador real, comprobar **GitHub Actions verde en el SHA de aceptación** y obtener revisión independiente. No fusionar ramas en estado rojo.

Política: [Estándar modular](../module-quality-standard.md) · [Plantilla](../module-audit-template.md).
