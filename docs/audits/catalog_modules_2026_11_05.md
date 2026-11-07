# Auditoría y rediseño de sucursales, usuarios, idiomas y productos

Fecha: 5 de noviembre de 2026. Rama de trabajo: `feature/fixes`.

## Hallazgos y correcciones

| Prioridad | Hallazgo | Corrección |
| --- | --- | --- |
| Alta | Un administrador podía consultar sucursales de otra organización mediante una URL directa. | Las consultas usan la organización actual; las políticas también comprueban la membresía organizacional. |
| Alta | El borrado lógico permitía ocultar sucursales o productos con registros de operación relacionados. | Se conserva el registro y se indica desactivarlo cuando existe inventario, documentos relacionados o solicitudes de precio pendientes. |
| Alta | El formulario de producto aceptaba adjuntos sin comprobar tamaño, contenido y pertenencia organizacional del identificador firmado. | Uppy local, identificación del contenido en servidor, límite de 5 MB y firma específica de producto vinculada a organización y usuario, además de comprobar el propósito del archivo. |
| Media | Una validación fallida podía perder la imagen elegida o intentar mostrar un archivo todavía no persistido. | La carga queda en Active Storage y se conserva con un identificador firmado durante la corrección del formulario. El envío convencional también funciona sin Uppy. |
| Media | El listado de idiomas excluía los inactivos incluso al filtrarlos. | La administración muestra todos los idiomas no eliminados. El selector utiliza únicamente idiomas activos con traducciones implementadas. |
| Media | La preferencia de idioma y el selector podían mostrar estados diferentes. | Se unificó la selección con el idioma efectivo, con alternativa activa y rechazo de cambios a idiomas no disponibles. |
| Media | El margen de un producto podía dividir por cero. | El margen devuelve un valor no disponible cuando no existe precio positivo o falta el costo. |
| Media | Los productos con nombres no transliterables podían producir rutas vacías; los nombres repetidos colisionaban en el identificador generado. | Se mantiene el identificador existente, se usa el código como alternativa y se diferencia un identificador repetido. Las rutas también admiten el ID. |
| Media | Una edición podía quitar clasificaciones antiguas que ya no figuraban entre las opciones activas. | El formulario conserva la categoría o clave fiscal seleccionada, aunque haya dejado de estar disponible para nuevas selecciones. |
| Media | El detalle de usuario ocultaba asignaciones de roles inactivos y la ayuda no describía el editor de acceso por sucursal. | Se muestran las asignaciones conservadas con su estado, iconos del sistema y ayuda actualizada. El resumen utiliza el estado de la membresía actual. |
| Media | Los campos de varias opciones comerciales podían comprimirse y superponerse. | Cuadrículas adaptables comprobadas en navegador, con controles separados y regresiones de anchura. |
| Media | El historial limitado a 20 movimientos podía ocultar solicitudes de precio antiguas. | Se pagina todo el historial, con acceso a las acciones autorizadas en cada página. |
| Media | Una referencia de clasificación inexistente podía producir un error de clave foránea al guardar un producto. | Se valida la referencia y se conserva el formulario con errores en sus campos. |
| Media | Los parámetros de una edición podían desincronizar el código de barras principal de su registro canónico. | La validación exige que el código principal coincida con el del producto. |
| Baja | Botones azules y paneles de distintos estilos rompían la identidad de Delta POS. | Espacios de trabajo, secciones, estados y acciones con la tipografía, iconos SVG y tonos esmeralda del sistema. |

## Comportamiento de las pantallas

- Sucursales: búsqueda por nombre, calle o ciudad; filtros de estado; paginación; datos de contacto y dirección; país con nombre localizado; creación y edición por secciones.
- Usuarios: creación, edición y detalle con navegación por identidad, roles, sucursales y preferencias. Búsqueda de roles y conteo de selecciones por sucursal. Se conserva el flujo de invitación y las acciones autorizadas de estado.
- Idiomas: listado y filtros coherentes, creación, edición y detalle en páginas completas, errores junto a los campos y navegación de retorno funcional. Se conserva compatibilidad de las respuestas Turbo existentes.
- Productos: identificación, imagen, precios, clasificación, variantes, presentaciones y códigos en secciones. El detalle conserva la comparación de ofertas de proveedores bajo sus propios permisos y añade historial paginado y simulación de precio. Todas las solicitudes de precio siguen accesibles, incluidas las anteriores a los últimos movimientos.
- Los listados mantienen las preferencias de paginación por usuario y organización. Las nuevas listas comerciales también utilizan el componente de paginación del sistema.
- Textos e información de validación disponibles en español, inglés y coreano. Los recursos nuevos se sirven localmente, sin CDN.

## Estructura comercial implementada

| Tabla | Uso |
| --- | --- |
| `product_variants` | Nombre, SKU, talla, color, modelo y atributos de variante. |
| `product_presentations` | Pieza, caja o paquete con conversión positiva a unidades base. |
| `product_barcodes` | Códigos principales y adicionales, opcionalmente asociados a variante o presentación. |
| `price_lists` | Lista organizacional, moneda, segmento, estado y vigencia. |
| `price_list_items` | Precio por producto y combinación exacta de variante/presentación, con vigencia. |
| `price_change_events` | Precio anterior, nuevo, moneda, motivo, solicitante y autorización. |
| `promotions` | Identificación, estado, vigencia y límites totales o por cliente. |
| `promotion_conditions` | Producto, categoría, cantidad base mínima, importe mínimo o segmento. |
| `promotion_benefits` | Descuento porcentual o por importe. |
| `promotion_redemptions` | Uso confirmado, clave de idempotencia y copia de las reglas aplicadas. |

Las relaciones comerciales pertenecen a una organización y tienen validaciones y claves foráneas compuestas para impedir asociaciones entre organizaciones o productos distintos.

## Reglas de precios y promociones

1. El precio base corresponde a una unidad. Una presentación convierte su cantidad a unidades base; un precio específico de presentación corresponde al paquete completo.
2. Los importes se calculan con decimales. La moneda de listas y promociones se fija al crearlas; cambiar de moneda requiere otro registro. Se conserva la consulta y el archivo de registros históricos si su moneda se desactiva. No se interpreta un precio base como si perteneciera a otra moneda cuando falta el precio de una lista.
3. Las vigencias incluyen el inicio y excluyen el final. Una fecha vacía deja ese extremo abierto; una fecha inválida genera un error.
4. No pueden superponerse precios para el mismo producto y opciones dentro de una lista. PostgreSQL también impide la superposición en operaciones simultáneas.
5. El usuario autorizado para crear un producto establece su precio inicial, que también queda registrado. Un cambio posterior del precio base requiere motivo. Un administrador lo autoriza al guardar; otro usuario con permiso de edición genera una solicitud pendiente y el precio vigente se conserva. La interfaz informa esta diferencia.
6. Una autorización no puede aplicar una solicitud ya revisada ni sustituir un precio que cambió desde la solicitud. El historial revisado no es editable.
7. La configuración de listas de precios y promociones y la autorización de solicitudes están reservadas a administradores. La lectura respeta los permisos del módulo de productos.
8. Todas las condiciones de una promoción se evalúan por renglón. Entre sus beneficios se elige el mayor descuento y, entre promociones coincidentes, se aplica **solo la más beneficiosa**, según la decisión del usuario.
9. El descuento nunca excede el importe del renglón. Los borradores y registros archivados no se aplican.
10. Los límites por cliente requieren un identificador estable del cliente. Cotizar no consume usos.
11. La confirmación de un uso es transaccional, comprueba los límites con bloqueo de la promoción y usa una clave de idempotencia por organización. Repetir la misma operación no duplica el uso; reutilizar su referencia para otra operación se rechaza.
12. EAN-8, EAN-13 y UPC-A comprueban longitud y dígito de control; también se admiten Code 128 y QR.

## Imágenes

Se admiten JPEG, PNG y WebP de hasta 5 MB. El servidor identifica el contenido y no confía únicamente en el nombre o la extensión. Los identificadores de cargas nuevas tienen una firma específica para el módulo, vinculada a su organización y usuario. Los metadatos proporcionados por un cliente o una firma genérica de Active Storage no bastan para autorizar un adjunto. Se conserva una imagen ya asociada durante ediciones que no la reemplazan.

Las cargas abandonadas se revisan después de 24 horas. El trabajo solo purga cargas de producto suficientemente antiguas que siguen sin adjuntarse; conserva archivos asociados, recientes o pertenecientes a otros módulos.

Uppy se incluye en el paquete local. Desarrollo y CI utilizan Node 24, de la misma versión principal que producción. Las dependencias JavaScript se verificaron con su auditoría de seguridad.

## Integración con ventas

Este repositorio todavía no contiene un flujo de venta, carrito o cierre de caja. La entrega incluye configuración comercial, simulación de precios y los servicios `Products::Quote` y `Products::RedeemPromotion`; no simula una integración de venta inexistente.

Al incorporar ventas, el servidor deberá obtener el cliente y su segmento desde datos autorizados, calcular el precio con las opciones del producto y registrar el uso únicamente dentro de la confirmación de la venta, con una referencia estable por renglón. Las variantes no crean inventarios independientes: el inventario existente continúa por producto y sucursal.

## Validación

Verificación local de la versión aplicada en `feature/fixes`:

| Comprobación | Resultado |
| --- | --- |
| Suite RSpec completa en Docker | **4.301 ejemplos, 0 fallos** |
| Cobertura de líneas | **98,97 %** · 11.888 / 12.012 |
| Cobertura de ramas | **95,25 %** · 3.487 / 3.661 |
| RuboCop | 1.026 archivos inspeccionados, 0 incidencias |
| Brakeman | 0 alertas |
| Dependencias Ruby | 0 vulnerabilidades; base de avisos actualizada el 4 de noviembre de 2026 |
| Dependencias JavaScript | 0 vulnerabilidades en la auditoría de las dependencias incorporadas |
| Traducciones | 249 archivos; 4.430 rutas por idioma; 0 diferencias o claves duplicadas |
| Aplicación local | Respuesta correcta de salud después de aplicar las migraciones y reiniciar los servicios |

La suite incluye solicitudes, modelos, políticas, servicios, concurrencia y navegador. Comprueba la carga real con Uppy, la conservación de imágenes ante errores, variantes y conversiones, paginación del historial, solicitudes y autorizaciones de precio, registros entre organizaciones, promociones y sus límites, navegación por teclado y pantallas estrechas. Las sesiones de navegador se cierran antes de limpiar la base de pruebas; los procesos de notificaciones también se detienen para evitar interferencias entre ejemplos.

La ejecución completa utilizó un contenedor temporal y la base aislada `sale_point_catalog_redesign_test`, con semilla 14736. Se conservaron los umbrales del proyecto: 98 % de líneas y 95 % de ramas.

Las tres migraciones comerciales están aplicadas al entorno local. Los conteos de desarrollo coinciden con los anteriores al cambio: 30 productos, 15 sucursales, 31 usuarios, 11 roles y 31 asignaciones. Las diez tablas comerciales están presentes. Las pruebas no utilizaron la base de desarrollo.
