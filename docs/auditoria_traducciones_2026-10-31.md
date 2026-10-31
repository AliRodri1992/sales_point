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

## Bloqueador principal: manual de usuario

El español ofrece 35 temas repartidos en siete capítulos: configuración inicial (5), seguridad (3), catálogos (4), proveedores (10), compras (5), finanzas (4) y comunicación (4). Los archivos `user_manual_sections.en.yml` y `user_manual_sections.ko.yml` incluyen esos mismos capítulos con `topics: []` y **sin procedimientos traducidos**. Se necesitan traducciones profesionales completas que conserven los procedimientos, pasos, advertencias y resultados originales. No es aceptable copiar la versión española dentro de los archivos de otros idiomas.

## Límites de esta auditoría automática

El análisis **no** certifica aún traducciones semánticamente correctas, ortografía o adecuación idiomática; tampoco demuestra que no haya textos literales incrustados en ERB, Ruby, JavaScript, correos o PDF, ni que todas las entradas en la tabla `translates` de PostgreSQL estén completas. Estas verificaciones requieren revisar consumidores de claves, traducciones dinámicas, datos de base de datos y pruebas de navegación por idioma.

## Comprobación continua

`python3 script/audit_i18n.py` informa el diagnóstico completo sin bloquear el pipeline por deuda preexistente. `I18N_STRICT_PARITY=1 python3 script/audit_i18n.py` devuelve error mientras existan hallazgos, para usar en la fase final. El hecho de que CI muestre verde en el job de I18n **no implica 100 % de cobertura** mientras el modo estricto no esté habilitado y aprobado.

**Estado:** auditoría de catálogos realizada con hallazgos abiertos; corrección/traducción completa y revisión visual aún pendientes.
