# Semillas de catálogos SAT / CFDI 4.0

## Diagnóstico y alcance

`db:seed` ahora incluye claves básicas **no exhaustivas** para las tablas fiscales
más usadas y permite cargar CSV completos y verificables para los 27 catálogos.
No se deben considerar las claves de referencia como la publicación íntegra del SAT.

- **Incluidos como claves iniciales:** CFDI (uso, comprobante, objeto,
  exportación, tipo factor, periodicidad, relación), formas y métodos de pago,
  impuestos (código), bancos frecuentes, monedas, unidades, países frecuentes,
  regímenes fiscales y **los 18 meses/bimestres**.
- **Requieren la fuente oficial para su cobertura completa:** productos y
  servicios, unidades, países, claves postales, colonias, estados, localidades,
  municipios, aduanas, patentes y pedimentos, rangos de tasas/cuotas, bancos,
  monedas, regímenes, y el resto de catálogos SAT.
- `SatTax` es una configuración interna de impuestos y **no equivale** al
  catálogo `c_Impuesto`; no insertar configuraciones fiscales por suposición.

## Fuente y formato

Descarga la versión vigente de los **Catálogos CFDI 4.0** del SAT en
https://omawww.sat.gob.mx/tramitesyservicios/Paginas/anexo_20.htm

Algunos catálogos, como bancos, pertenecen a complementos distintos y deben
provenir de su catálogo correspondiente. Revisa la fecha de publicación y
vigencia; no uses una captura antigua como si fuera el catálogo vigente.

Convierte/exporta los datos verificados a CSV UTF-8 **con encabezados de columnas
idénticos a los nombres del esquema Rails**, un archivo por tabla. El seed no
interpreta automáticamente la disposición y encabezados cambiantes del Excel
original: **no renombres columnas a ojo**. Se conservan códigos como texto,
incluidos ceros iniciales y claves compuestas.

Ejemplos:

```text
db/seeds/data/sat/sat_voucher_types.csv
  code,description,valid_from,valid_to,status
  I,Ingreso,,,true

db/seeds/data/sat/sat_product_service_keys.csv
  code,description,includes_vat,includes_ieps,valid_from,valid_to,status
  01010101,<descripción verificada con el SAT>,,,,true
```

La segunda fila es **solo el formato ilustrativo**; no la uses como registro real
sin reemplazar la descripción por su valor verificado.

No incluyas `id`, `created_at`, `updated_at` ni `deleted_at` en los CSV.
El importador valida los encabezados, las claves y las columnas obligatorias.
El seed importa primero los archivos oficiales disponibles y después rellena las claves básicas. Inserta por lotes y omite claves ya existentes o archivadas para no modificar
descripciones editadas manualmente ni duplicar datos al repetir el seed.
Las columnas `valid_from` y `valid_to` permiten conservar vigencias históricas.

## Ejecución

```bash
# La carga básica funciona sin descargas ni servicios externos.
docker compose -f docker-compose.dev.yml exec web bin/rails db:seed

# Para una carga completa, coloca los CSV verificados en un directorio local
# y habilita el modo estricto; cualquier CSV que falte causa error explícito.
docker compose -f docker-compose.dev.yml exec \
  -e SAT_CATALOGS_DIR=/rails/db/seeds/data/sat \
  -e SAT_CATALOGS_REQUIRED=true web bin/rails db:seed
```

La ruta indicada debe existir **dentro del contenedor**; bajo desarrollo,
`db/seeds/data/sat` se comparte con `/rails`. Se informa la lista de
catálogos sin CSV y el total de filas incorporadas, en lugar de declarar que
todos están cargados. El modo estricto verifica que todos los archivos estén disponibles antes de cualquier importación; es opcional, no lo actives hasta tener
el conjunto verificado y completo.

**IMPORTANTE:** que los `seeds` terminen no prueba la vigencia fiscal del
conjunto importado; antes de emitir CFDI hay que verificar fecha de actualización
del SAT, hashes de origen, claves y reglas del Anexo 20.
