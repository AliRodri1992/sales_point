# Tarjetas bancarias de proveedores

## Vista de listado

`/admin/suppliers/:supplier_id/bank_accounts` muestra las cuentas autorizadas del proveedor como tarjetas visuales, en columnas responsivas. La identidad BBVA, Banorte o Santander es decorativa; las demás instituciones usan una identidad esmeralda con su nombre disponible. Cada tarjeta contiene:
- solo el identificador enmascarado de cuenta o los cuatro últimos dígitos opcionales de la tarjeta;
- vencimiento de tarjeta **solo si está registrado**; las cuentas bancarias tradicionales no tienen fecha de expiración;
- distintivo Activa/Inactiva (Inactiva representa cuenta archivada) y corona de Principal antes del menú;
- menú protegido por permisos para editar, archivar o recuperar.
- tarjeta de **Agregar cuenta bancaria** (solo usuarios con permiso y proveedores activos).

El filtro de banco y la búsqueda actúan del lado del servidor; las pestañas Todas / Activas / Inactivas admiten paginación. Los registros archivados no se editan directamente y se recuperan como no principales.

## Privacidad

Nunca se captura ni almacena el número completo de una tarjeta, su CVV, NIP ni ningún secreto en los nuevos campos. `card_last_four`, `card_expiration_month` y `card_expiration_year` son opcionales y validados como conjunto. El número de cuenta/CLABE existente sigue cifrado y solo se presenta enmascarado en el listado. La revelación completa conserva su endpoint, permisos y auditoría existentes.

La representación visual usa clases TailwindCSS locales, sin librerías externas y sin iconos remotos.
