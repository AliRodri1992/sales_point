# Compras, recepción y trazabilidad — Delta POS (fase 5)

El módulo reside en `feature/suppliers`, bajo `/admin`. Requiere una organización activa y una membresía activa. Las autorizaciones individuales son administradas por Pundit (`purchases.view`, `purchases.create`, `purchases.approve`, `purchases.receive`, `purchases.returns`).

## Flujo operativo

1. **Solicitud de compra:** `PurchaseRequest` con sus `PurchaseRequestItem` por sucursal. Borrador → enviada → aprobada o rechazada. Se impide aprobar la solicitud propia.
2. **Cotización:** `PurchaseQuotation` con precios, moneda, presentación y fecha de validez. La cotización aceptada permite prellenar una orden conservando los precios negociados.
3. **Orden:** `PurchaseOrder` y `PurchaseOrderItem`. Borrador → pendiente de aprobación → aprobada → enviada (`ordered`). Se registran decisiones en `PurchaseApproval`; las órdenes con recepciones no pueden cancelarse.
4. **Recepción:** `GoodsReceipt` y `GoodsReceiptItem`. Cada entrega puede ser total o parcial; registra cantidades entregadas, aceptadas, dañadas y no clasificadas. La cantidad aceptada ingresa a `Inventory` de la sucursal mediante `Purchases::Receive`, `Purchases::ReceiveLine` y `Purchases::ReceiveStock`, usando transacciones y bloqueos. La operación requiere `idempotency_key` para prevenir doble contabilización.
5. **Lotes y series:** `InventoryLot` e `InventorySerial`. Los productos pueden configurarse como `none`, `lot` o `serial`. El stock dañado permanece en cuarentena y no suma a las existencias disponibles. No se acepta stock caducado como disponible.
6. **FEFO y devoluciones:** `Inventories::FefoAllocator` prioriza las caducidades más próximas al consumir inventario. `PurchaseReturn` y `PurchaseReturnItem` permiten devolver unidades aceptadas (descontando stock) o dañadas en cuarentena (sin descontar el stock disponible por segunda vez), con control de cantidades y estado.
7. **Costeo:** `Purchases::Costing` calcula `landed_unit_cost` y guarda `PurchaseCostAllocation`, considerando el valor negociado, descuentos, fletes, seguros, gastos reales, impuestos no recuperables ya incluidos en la orden y tipo de cambio definido en la orden. Se conservan los importes asignados por recepción.

## Consideraciones contables y operativas

- La `quantity` de órdenes y recepciones está expresada en unidades base; `units_per_package` convierte los precios cotizados por presentación.
- La moneda de la orden se mantiene separada del valor convertido con `exchange_rate`. El tipo de cambio es un dato explícito, no una cotización en tiempo real.
- Una devolución requiere disponibilidad física en el lote correspondiente; la cantidad original recibida no es equivalente a la cantidad aún disponible.
- Las entradas y salidas de mercancía aceptada generan `InventoryMovement` con origen polimórfico. Los movimientos son inmutables; los registros de cuarentena conservan su trazabilidad en los lotes y versiones de PaperTrail.
- La recepción parcial deja saldo pendiente en la orden. El cierre con diferencias impide nuevas recepciones y conserva el historial existente.
- **Integración futura con ventas:** los módulos que descuenten productos con control por lotes o series deben invocar `Inventories::FefoAllocator` para mantener la selección FEFO. El módulo de ventas no forma parte de la fase 5.

## Pruebas y calidad

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate
docker compose -f docker-compose.dev.yml exec web bin/rails db:seed
docker compose -f docker-compose.dev.yml exec web env COVERAGE=true bundle exec rspec
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop
```

Pruebas principales: `spec/services/purchases/receive_spec.rb`, `process_return_spec.rb`, `costing_spec.rb`, `purchase_workflow_spec.rb`, `spec/requests/admin/purchase_cycle_spec.rb` y `spec/requests/admin/purchase_requests_integration_spec.rb`.

En el despliegue de una organización, conceder sólo los permisos necesarios a compradores, autorizadores, receptores y responsables de devoluciones. No fusionar ni desplegar si GitHub Actions detecta errores.
