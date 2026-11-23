# Contrato de integración de Promociones con la venta

**Estado:** CONTRATO PROPUESTO, SIN FLUJO DE CHECKOUT PROPIO EN EL REPOSITORIO.
**Módulo propietario:** Promociones. **Dependencia:** módulo de ventas/caja.

## API actual y garantías

- Consultar importes con `Products::Quote.new(product:, quantity:, ...).call` para calcular precios usando solo campañas activas, sin escribir `PromotionRedemption`.
- Para probar una campaña en borrador, `Products::Quote.new(product:, promotion:, ...).preview` no registra consumos. La salida del simulador puede incluir `explanation` cuando la campaña seleccionada no aplica.
- Cuando una venta **se confirma realmente**, invocar `Products::RedeemPromotion.new(product:, idempotency_key:, customer_reference:, quantity:, ...).call` **una vez por línea descontada**. El servicio vuelve a calcular dentro de locks y crea una redención con snapshot, claves únicas por organización y cuotas globales/por cliente.
- `idempotency_key` debe ser estable para la misma operación confirmada y distinto entre líneas. No reutilizarlo en otra operación, producto, cantidad, cliente, variante o presentación. `IdempotencyConflict` significa que la clave se utilizó con contexto distinto; no reintentar con una clave aleatoria.
- `Unavailable` indica que la promoción no es aplicable o se agotó. El consumidor debe rechazar la confirmación del descuento o recotizar explícitamente según la política de caja, no persistir un descuento inconsistente.

## Responsabilidades faltantes para cerrar PROM-006

1. La transacción de venta, sus líneas y `PromotionRedemption` deben confirmarse o revertirse de forma atómica. Si el servicio de ventas está en otra aplicación, definir el mecanismo de entrega/reintentos y conciliación.
2. Definir semántica de cancelación, devolución y reverso con auditoría. Las redenciones existentes son deliberadamente inmutables: no editarlas ni eliminarlas para 'devolver' el cupo. Implementar compensaciones verificables cuando el flujo de ventas exista.
3. Probar dos ventas concurrentes usando el último cupo, cuotas por cliente, doble clic y reintentos de red, precios cambiados entre cotización y venta, operaciones con distintos productos que reutilizan la misma clave, moneda/variante/presentación y fallo al escribir la venta.
4. Probar el contrato con permisos y organización, y evitar pasar claves, clientes o detalles de canje a payloads de métricas/observabilidad.

## Condición de aceptación

No marcar PROM-006 como completado hasta ejecutar una integración de venta confirmada con rollback y reconciliación de cancelaciones contra un módulo real, y dejar constancia de una suite de regresión aprobada.
