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

## Pestaña «Ver proveedor» → Cuentas bancarias

La pestaña `/admin/suppliers/:id?tab=bank_accounts` utiliza **el mismo parcial de tarjeta**
`admin/supplier_bank_accounts/_account_card` que el administrador de cuentas bancarias.
Incluye búsqueda, filtro de institución, pestañas Todas/Activas/Inactivas con contadores,
paginación y la tarjeta de alta para proveedores activos y usuarios con autorización.
Los filtros emplean parámetros `banks_q`, `banks_bank`, `banks_status`, `banks_page`
y conservan `tab=bank_accounts` al navegar. Por defecto muestra solo las cuentas activas;
las archivadas aparecen al seleccionar Inactivas.

Los datos se consultan exclusivamente a través de la asociación del proveedor de la
organización autorizada. No se muestran moneda, titular, cuenta completa ni panel lateral
de información en las tarjetas. El botón «Administrar cuentas bancarias» sigue enlazando
a la vista completa para tareas especializadas.
