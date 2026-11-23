# Operar Delta POS con Docker

El [archivo Compose de desarrollo](../docker-compose.dev.yml) define cinco servicios. Sigue la [instalación](installation.md) antes de iniciarlos por primera vez.

| Servicio | Función | Qué revisar si falla |
| --- | --- | --- |
| `web` | Prepara la base e inicia Puma en el puerto 3000. | Conexión con PostgreSQL y salida de `db:prepare`. |
| `assets` | Ejecuta los procesos de [compilación de recursos](../Procfile.assets.dev). | Errores de JavaScript o CSS cuando la interfaz queda desactualizada. |
| `db` | Ejecuta PostgreSQL 16 y conserva los datos en `pgdata`. | Estado del healthcheck y disponibilidad del puerto 5432. |
| `redis` | Ejecuta Redis y conserva sus datos en `redisdata`. | Conectividad de los clientes por el puerto 6379. |
| `sidekiq` | Procesa trabajos con la [configuración del worker](../config/sidekiq.yml). | Conexión con Redis y excepciones al ejecutar trabajos. |

## Operación habitual

```sh
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml logs --tail=100 web assets sidekiq
docker compose -f docker-compose.dev.yml exec web bin/rails console
docker compose -f docker-compose.dev.yml stop
```

Para reanudar los servicios, usa `docker compose -f docker-compose.dev.yml up -d`. Si Sidekiq falla al cargar la biblioteca nativa de imágenes, ejecuta `bash bin/repair-sidekiq-vips` desde la raíz. El [script de reparación](../bin/repair-sidekiq-vips) comprueba libvips tanto en la imagen como en el contenedor.

## Producción

El [Dockerfile de producción](../Dockerfile) y la [configuración de Kamal](../config/deploy.yml) son los puntos de partida para un despliegue. Configura los hosts, el registro de imágenes y los secretos del entorno de destino. Revisa las conexiones de [PostgreSQL](../config/database.yml), el adaptador de trabajos del [entorno de producción](../config/environments/production.rb) y los requisitos de [cifrado financiero](financial_encryption.md) antes de preparar las bases de datos.
