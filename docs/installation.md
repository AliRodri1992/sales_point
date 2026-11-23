# Instalar Delta POS en desarrollo

Necesitas Git, Docker en ejecución y Docker Compose v2. Los contenedores incluyen Ruby, las gemas y las herramientas para compilar los recursos del frontend.

## Preparar el repositorio

```sh
git clone https://github.com/AliRodri1992/sales_point.git
cd sales_point
```

Crea `.env.development` en la raíz del proyecto. Estos valores corresponden exclusivamente al PostgreSQL del [Compose de desarrollo](../docker-compose.dev.yml):

```dotenv
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=sale_point_development
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
```

El archivo queda fuera de Git. Si tu entorno utiliza las credenciales cifradas del equipo, configura la clave correspondiente por el canal privado del proyecto. Para las claves de los datos bancarios, consulta la [guía de cifrado financiero](financial_encryption.md).

## Iniciar y comprobar

```sh
docker compose -f docker-compose.dev.yml up --build -d
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml logs -f web
```

El primer arranque construye las imágenes. Cuando PostgreSQL está listo, el servicio web ejecuta `db:prepare` e inicia Puma en el puerto 3000. Sal del seguimiento de logs con Ctrl+C. Abre [la aplicación](http://localhost:3000) o verifica que Rails responde con `curl -f http://localhost:3000/up`.

Si falla la conexión con PostgreSQL, revisa el estado de `db` y comprueba que el host en `.env.development` sea `db`. Si la página carga sin estilos, revisa los logs de `assets`. Los comandos por servicio están en la [guía de Docker](docker.md).
