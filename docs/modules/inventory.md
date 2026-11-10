# Inventarios — Delta POS

## Estado y alcance

El espacio operativo vive en `/admin/inventory` y el detalle de cada sucursal en
`/admin/branches/:branch_id/inventories`. Construido sobre los modelos y servicios existentes:
`Inventory`, `InventoryMovement`, `InventoryLot`, `InventorySerial`,
`Inventories::ApplyMovement` y `Purchases::Receive`.

- Vista general multi-sucursal limitada al ámbito de la organización y las sucursales autorizadas.
- Métricas de registros, unidades registradas, agotados y niveles bajos.
- Búsqueda por nombre, código, SKU y código de barras; filtros por sucursal, estado y seguimiento;
  ordenación de lista blanca, etiquetas de filtros activos y paginación por preferencias.
- Vista por sucursal para asociar un producto, gestionar mínimos/máximos, registrar ajustes
  con referencia opcional, consultar últimos movimientos y navegar a lotes/series.
- Los controles de administración se muestran solo con autorización y si el estado de sucursal lo permite.
- Búsqueda automática con Stimulus, formulario GET funcional sin JavaScript, diseño Tailwind responsive.
- Traducciones `es`, `en` y `ko`.

## Seguridad y consistencia

`InventoryPolicy` comprueba pertenencia activa y el alcance de sucursales:
`inventory.access` o `inventory.view` permiten la lectura; `inventory.manage` autoriza
altas y edición de umbrales; `inventory.adjust` habilita ajustes. Los administradores
con acceso vigente a su organización conservan la operación. Los roles globales con el permiso de Inventario conceden acceso a las sucursales de la organización;
los roles limitados a una sucursal solo pueden ver y operar esa sucursal, incluso cuando el usuario
tiene otros roles sin autorización de Inventario. El rol de sistema `inventory` recibe los cuatro
permisos al sembrar.

Las existencias no pueden editarse mediante parámetros del formulario. Los cambios pasan por
`Inventories::ApplyMovement`, que trabaja con transacciones, bloqueos, verificaciones de
cantidades y registros inmutables. La selección de lote es obligatoria cuando corresponde;
el ajuste manual de productos seriados sigue deshabilitado. Se conservan las reglas
de las sucursales cerradas o suspendidas.

## Operaciones fuera de esta entrega

El servicio `Inventories::Transfer` preexistente aún no cuenta con un flujo nuevo de
transferencia/conciliación por lotes y números de serie. Los conteos físicos completos
y la integración con ventas se desarrollarán posteriormente; no deben activarse
solo como cambios de UI sin su contrato transaccional.

## Verificación requerida

```bash
bundle exec rspec spec/requests/admin/inventory_overview_spec.rb \
  spec/requests/admin/branch_inventories_validation_spec.rb \
  spec/requests/admin/inventory_controller_paths_spec.rb
bundle exec rubocop app/controllers/admin/inventory_overview_controller.rb \
  app/controllers/admin/inventories_controller.rb app/policies/inventory_policy.rb
bin/rails zeitwerk:check
bin/rails db:migrate
```

Revisar la interacción en navegador: búsqueda automática, teclado, zoom 200 %, cambio de
idioma, estados sin resultados, errores 422 y sucursales cerradas. Aceptación sujeta a CI
en el SHA final de `feature/fixes`.
