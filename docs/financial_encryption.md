# Cifrado de datos bancarios — Delta POS

`SupplierBankAccount` utiliza Active Record Encryption para proteger el número de cuenta y la CLABE.
Nunca desactives este cifrado para poder ejecutar las semillas.

## Desarrollo local con Docker Compose

En `development`, si no existen claves de Active Record Encryption en las variables de
entorno ni en Rails credentials, la aplicación genera **una sola vez** tres claves aleatorias
en `config/financial_encryption.local.json`, protegido con permisos `0600` e ignorado
por Git. El archivo se conserva al reiniciar los contenedores y es compartido por los
servicios `web` y `sidekiq` porque ambos montan el directorio del proyecto.

Después de actualizar `feature/suppliers`, vuelve a ejecutar:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:seed
```

En instalaciones nuevas también basta con iniciar Docker Compose; las claves se
crean al inicializar Rails, antes de ejecutar `db:prepare` o `db:seed`.

**Importante:** conserva una copia de seguridad de este archivo junto con la base de datos.
Si lo eliminas, regeneras o reemplazas después de crear cuentas bancarias, los
valores cifrados con las claves anteriores dejarán de poder descifrarse. Si ya
tenías cuentas bancarias cifradas, recupera sus claves originales antes de continuar.

## Staging y producción

No se generan claves automáticamente fuera de `development`. Configura las
mismas tres claves de forma persistente en el gestor de secretos del despliegue,
o en Rails credentials:

```text
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
```

Puedes generar los valores para un entorno nuevo con `bin/rails db:encryption:init`.
No los publiques, no los guardes en Git y no los cambies sin un procedimiento de
rotación de claves y migración de datos.

En desarrollo, las variables de entorno tienen prioridad sobre Rails credentials
y sobre el archivo local. Si existe una configuración externa incompleta, Rails
emitirá un error claro en vez de crear claves mezcladas y potencialmente incompatibles.

## Validación

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:seed
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/initializers/financial_encryption_configuration_spec.rb spec/models/supplier_bank_account_spec.rb spec/seeds/supplier_commercial_examples_spec.rb
```

La segunda ejecución de `db:seed` debe conservar las cuentas existentes sin duplicarlas.
