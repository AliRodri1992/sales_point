# Delta POS

Delta POS reúne en un panel la administración de productos, precios, promociones, inventario por sucursal, compras y cuentas por pagar. El acceso depende de la organización activa y de los permisos del usuario. La interfaz está disponible en español, inglés y coreano.

## Ejecutar en desarrollo

Se requiere Docker con Compose v2. Desde la raíz de `sales_point`, prepara `.env.development` con los valores de la [guía de instalación](docs/installation.md) y ejecuta:

```sh
docker compose -f docker-compose.dev.yml up --build -d
docker compose -f docker-compose.dev.yml logs -f web
```

Cuando Puma esté escuchando, abre [Delta POS en localhost](http://localhost:3000). El servicio `web` prepara la base de datos al arrancar. El servicio `assets` recompila JavaScript y CSS durante el desarrollo.

## Áreas del sistema

| Área | Punto de entrada | Operaciones |
| --- | --- | --- |
| Catálogos | `/admin/products`, `/admin/categories` | Consultar productos, organizarlos por categoría y revisar sus referencias. |
| Precios y promociones | `/admin/price_lists`, `/admin/promotions` | Configurar listas y promociones, consultar su vista previa y cambiar su estado. |
| Inventario | `/admin/inventory`, `/admin/branches` | Consultar existencias y registrar ajustes por sucursal. |
| Compras | `/admin/purchase_requests`, `/admin/purchase_orders` | Tramitar solicitudes y órdenes, registrar recepciones y devoluciones. |
| Proveedores y finanzas | `/admin/suppliers`, `/admin/account_payables` | Administrar proveedores, facturas, pagos y notas de crédito. |
| Administración | `/admin/users`, `/system_roles` | Gestionar usuarios, roles y permisos. |
| Ayuda | `/admin/guide` | Consultar la guía de uso desde el panel. |

Consulta el [mapa de rutas de Rails](config/routes.rb) para identificar el verbo HTTP y el controlador de cada acción.

## Desarrollo y calidad

La aplicación utiliza Rails 8.1, PostgreSQL, Redis y Sidekiq. La interfaz combina ERB, Hotwire, Stimulus y Tailwind CSS. Para ejecutar RSpec en un contenedor temporal con su propia configuración de pruebas:

```sh
bash bin/overcommit-rspec
```

- [Documentación técnica](docs/README.md) y [guías funcionales](docs/modules/index.md)
- [Pruebas, cobertura y CI](docs/testing.md)
- [Reglas de contribución](AGENTS.md), [estándar modular](docs/quality/module-quality-standard.md) y [expedientes por módulo](docs/quality/modules/README.md)

Desarrollado por [Ivan Rodriguez](https://github.com/AliRodri1992).
