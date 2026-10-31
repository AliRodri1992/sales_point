# Auditoría de traducciones Delta POS — 31 de octubre de 2026

**Rama:** `feature/suppliers`. Idiomas: `es` (español mexicano), `en` (inglés), `ko` (coreano). No se propone introducir `es-MX`.

## Método y evidencia

Se amplió `script/audit_i18n.py` para consolidar todos los catálogos YAML, comparar rutas hoja de traducción, interpolaciones, cadenas vacías, longitud de listas de contenido y capítulos sin temas. La ejecución de GitHub Actions del commit `b2bf9fa9`, trabajo *Rails I18n and YAML audit*, reportó:

- 198 archivos YAML revisados, sintaxis y carga de Rails correctas.
- `es`: 3,320 rutas hoja; `en`: 3,322; `ko`: 3,322.
- **32 hallazgos del diagnóstico**. Se trata de resultados de varias reglas: una ausencia de temas puede aparecer a la vez como lista incompleta y como capítulo vacío; no deben interpretarse como 32 fallos independientes.
- 14 listas de capítulos incompletas (7 inglés, 7 coreano), más 14 señales de capítulos vacíos.
- 4 claves adicionales en idiomas secundarios con respecto a español:
  - `en.admin.languages.statuses.inactive`
  - `en.admin.onboarding.completed.icon`
  - `ko.admin.languages.statuses.inactive`
  - `ko.admin.users.form.fields.invalid_message`
  Una clave EXTRA no significa necesariamente que la traducción sea errónea: debe investigarse si se requiere añadirla en `es` o eliminarla.
- El auditor no notificó claves ausentes respecto de las hojas `es`, interpolaciones distintas ni cadenas vacías en estas reglas concretas.

## Adecuaciones publicadas

Se completó la traducción de los **35 temas y sus procedimientos** en los siete capítulos de la guía para inglés y coreano. Se mantuvieron los identificadores y las cantidades de procedimientos y pasos que ya existían en español:

- Configuración inicial: 5 temas.
- Seguridad, roles e idiomas: 3 temas.
- Catálogos, inventario y clientes: 4 temas.
- Proveedores y su expediente: 10 temas.
- Compras y recepción: 5 temas.
- Finanzas: 4 temas.
- Comunicación: 4 temas.

Se eliminaron los mensajes del centro de aprendizaje que aseguraban que las instrucciones detalladas solo estaban en español.

Se resolvieron las diferencias de claves detectadas inicialmente: `admin.languages.statuses.inactive` se incorporó en `es`; `admin.onboarding.completed.icon` se incorporó donde faltaba; se alinearon los indicadores de resultado del asistente; y se retiró `admin.users.form.fields.invalid_message` de `ko`, ya que era una entrada mal ubicada con un error tipográfico.

Se reforzó `script/audit_i18n.py` para verificar no solo la presencia de capítulos, sino también los identificadores de los temas, el número de procedimientos y la cantidad de pasos y campos requeridos. El job de I18n en GitHub Actions ahora usa `I18N_STRICT_PARITY=1`, de modo que los hallazgos de paridad bloquean el CI. **La confirmación definitiva depende del resultado del job para el commit más reciente.**

### Comprobación independiente de estructura

Se compararon los 35 temas españoles con ambos archivos traducidos en la rama. Los 35 identificadores coinciden y no se encontraron diferencias en cantidades de procedimientos o pasos.

## Límites de esta auditoría automática

El análisis **no** certifica aún traducciones semánticamente correctas, ortografía o adecuación idiomática; tampoco demuestra que no haya textos literales incrustados en ERB, Ruby, JavaScript, correos o PDF, ni que todas las entradas en la tabla `translates` de PostgreSQL estén completas. Estas verificaciones requieren revisar consumidores de claves, traducciones dinámicas, datos de base de datos y pruebas de navegación por idioma.

## Comprobación continua

`python3 script/audit_i18n.py` informa el diagnóstico completo sin bloquear el pipeline por deuda preexistente. `I18N_STRICT_PARITY=1 python3 script/audit_i18n.py` devuelve error mientras existan hallazgos, para usar en la fase final. El hecho de que CI muestre verde en el job de I18n **no implica 100 % de cobertura** mientras el modo estricto no esté habilitado y aprobado.

**Estado:** auditoría de catálogos realizada con hallazgos abiertos; corrección/traducción completa y revisión visual aún pendientes.
