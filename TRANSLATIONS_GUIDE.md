# Delta POS — Idiomas y traducciones

## Contrato de los idiomas

- Los idiomas configurados por la aplicación son `es`, `en` y `ko` (`config/application.rb`).
- Solo los registros **activos**, **no eliminados** y **configurados** aparecen en el selector.
- Un idioma adicional puede registrarse como inactivo, pero no activarse hasta que
  sus traducciones estén implementadas y su código forme parte de
  `config.i18n.available_locales`. Registrar un idioma no lo traduce.
- El código del idioma es inmutable tras el alta; el idioma predeterminado
  no puede desactivarse ni retirarse.
- Las banderas identifican países y no determinan el idioma.

## Fuentes de traducción

`config/initializers/i18n_database_backend.rb` configura la cadena:

1. **PostgreSQL**: claves activas en `translates`, relacionadas con `languages`.
   Sirven como overrides editables.
2. **YAML**: `config/locales/**/*.yml`, fallback cuando no existe una clave en la base.
3. El comportamiento normal de I18n para claves ausentes.

El backend se configura incluso antes de que existan las tablas; cuando se aplican
las migraciones, la carga se reintenta. Tras crear, modificar o eliminar una
traducción o modificar un idioma, se invalida la caché. La invalidación es
inmediata en el proceso actual y se comparte con otros procesos cuando
`Rails.cache` utiliza un almacén compartido (Redis/SolidCache). Se consulta
la versión compartida como máximo una vez por segundo por proceso.

**No sobrescribas traducciones editadas directamente en la base** si ejecutas
`translations:load` o `db:seed`: ambas tareas importan los valores de YAML
y actualizan los registros de las mismas claves. Se recomienda definir una
política de fuente de verdad antes de editar traducciones en producción.

## Instalación y carga de archivos

```bash
bin/rails db:migrate
bin/rails translations:load
bin/rails translations:stats
```

También se puede ejecutar `bin/setup-translations.sh` desde cualquier
directorio. La tarea `translations:load` reconoce nombres como
`en.yml`, `devise.es.yml` y `es.registration.yml` (y sus equivalentes en
`en` y `ko`). Omite `devise.security_extension.*.yml`.

La carga es idempotente por clave e idioma. Los archivos YAML y JSON-válido
como YAML se interpretan con `YAML.safe_load_file`.

## Seguridad y validación

- Las validaciones de idioma se hacen en el modelo y se muestran junto a cada campo.
- Las claves de traducciones son únicas por idioma entre registros activos.
- No se permite alterar el código de un idioma existente.
- `PATCH /language` solo admite idiomas seleccionables.
- La administración requiere permisos Pundit `languages.access` y los
  permisos granulares de la acción.
- El estado de la interfaz no sustituye las verificaciones del servidor.

## Pruebas

```bash
bundle exec rspec spec/models/language_spec.rb spec/models/translate_spec.rb \
  spec/requests/admin/languages_spec.rb spec/requests/language_switch_spec.rb \
  spec/requests/application_locale_spec.rb
```

Comprueba también `bundle exec rubocop` y el flujo de CI antes de integrar
los cambios. Las traducciones YAML faltantes deben revisarse con un auditor
de cobertura; el fallback no equivale a una traducción de calidad.
