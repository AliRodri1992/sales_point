# Productos — Delta POS

## Alcance operativo

El catálogo se administra en `/admin/products`, con acciones de listado, búsqueda, alta, detalle, edición y baja lógica. El módulo conserva organización, permisos granulares y registros comerciales e históricos.

## Modelo y relaciones

- **Identificación:** código obligatorio (máximo 50 caracteres, único por organización ignorando mayúsculas/minúsculas), nombre obligatorio (máximo 100), SKU opcional (máximo 50), código de barras principal opcional (máximo 100, caracteres imprimibles Code 128), descripción (máximo 500).
- **Precios:** precio base por unidad obligatorio y no negativo; costo de adquisición opcional. El precio base se registra inicialmente y sus cambios posteriores requieren motivo y, para usuarios no administradores, autorización.
- **Clasificación y fiscal:** categoría, unidad SAT y impuesto SAT son referencias opcionales; se validan en el servidor.
- **Opciones comerciales:** variantes (`ProductVariant`), presentaciones con conversiones a unidades base (`ProductPresentation`) y códigos de barras adicionales (`ProductBarcode`). Las variantes pueden distinguir talla, color y modelo. Los códigos adicionales persistidos se retiran mediante baja lógica; el principal se gestiona desde el campo del producto.
- **Disponibilidad:** estado activo/inactivo, destacado, posición, slug y `deleted_at` de baja lógica.
- **Imágenes:** Active Storage y Uppy local, exclusivamente JPEG/PNG/WebP hasta 5 MB con verificación en servidor, firma por usuario y organización y vencimiento temporal.
- **Rastreo de existencias:** `tracking_mode` con valores `none`, `lot` y `serial`. No se permite cambiar el modo una vez que existan existencias o historial de lotes/movimientos.

**Existencias, mínimo y máximo** no están en `Product`: pertenecen a `Inventory` por sucursal. `InventoryLot`, `InventorySerial` e `InventoryMovement` son propiedad del módulo Inventario. El listado de Productos presenta el total de existencias y solo consulta su contrato de lectura.

## Listado y filtros

Se busca por nombre, código, SKU, código principal, códigos secundarios y variantes. Los filtros incluyen estado, categoría, destacado, tipo de seguimiento, precio mínimo/máximo y existencias: con existencias, agotados y bajo mínimo en alguna sucursal.

El formulario ofrece búsqueda automática (debounce), estado siempre visible y el resto dentro de **Filtros avanzados** desplegables. La selección utiliza dropdowns Delta; el de categoría admite búsqueda. El botón **Aplicar filtros** es compacto, junto con **Limpiar**. Chips de filtros activos permiten quitar criterios individualmente. La navegación completa actualiza la URL en filtros, ordenamiento y paginación para conservar resultados al recargar, retroceder o cambiar el tamaño de página. Los valores numéricos inválidos de consulta se ignoran de manera segura. La paginación usa las preferencias del sistema.

## Precios, historial y cotizaciones

- `Products::SaveCatalogEntry` crea/edita productos y registra el precio inicial o la solicitud de cambio.
- `PriceChangeEvent` conserva histórico y autorización, protegido contra revisiones obsoletas.
- `Products::Quote` calcula importes decimales, conversiones y promoción aplicable, sin consumir redenciones.
- La vista ofrece únicamente listas vigentes; muestra el segmento de cada lista y explica un rechazo por segmento o moneda. El servidor vuelve a validar todas las opciones seleccionadas.
- Los importes del catálogo muestran el código de moneda base organizacional para evitar ambigüedad entre MXN y otras divisas.

## Seguridad y restricciones

`ProductPolicy` y `accessible_products` impiden ver o modificar productos de otras organizaciones. Los adjuntos firmados incluyen organización y usuario. `acts_as_paranoid` preserva registros retirados; el historial operativo impide retiradas incompatibles. La base de datos incorpora índices únicos parciales por organización para códigos de productos, SKU y códigos de barras sin distinguir mayúsculas/minúsculas.

Para evitar conflictos entre SKU base y SKU de variante también existen validaciones de modelo en ambos sentidos. **Pendiente:** certificar mediante pruebas concurrentes su garantía transaccional conjunta entre tablas.

## Pruebas y seguimiento

- `spec/requests/admin/products_spec.rb`: rutas, permisos, filtros avanzados y errores.
- `spec/requests/admin/product_tenant_access_spec.rb`: aislamiento organizacional.
- `spec/models/product_spec.rb`: atributos, integridad de identificadores y seguimiento.
- `spec/services/products/*`: precios, promociones, cotizaciones, carga de imágenes y concurrencia comercial.
- `spec/features/catalog_redesign_browser_spec.rb` y `spec/features/global_branded_selects_spec.rb`: interfaz y dropdowns.

El expediente de calidad con IDs estables está en [`docs/quality/modules/products.md`](../quality/modules/products.md). **No considerar el módulo verificado sin RSpec focalizado, navegador y GitHub Actions en el SHA final.**
