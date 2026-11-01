# Fase 6 — Facturación y cuentas por pagar

Implementado en \`feature/suppliers\` con rutas bajo \`/admin\`.

## Componentes

- \`SupplierBankAccount\`: cuentas del proveedor cifradas mediante Active Record Encryption; mostrar exclusivamente los últimos cuatro dígitos salvo autorización especial y auditoría.
- \`SupplierInvoice\` y \`SupplierInvoiceLine\`: facturas manuales o CFDI 4.0, PDF/XML privados en Active Storage, UUID único por organización.
- \`AccountPayable\`: una obligación por factura confirmada; saldo derivado de pagos confirmados y créditos aplicados.
- \`SupplierPayment\` y \`SupplierPaymentAllocation\`: pagos y aplicación a deudas con bloqueos y transacciones para impedir sobrepagos. La reversión conserva los movimientos y los excluye del saldo pagado.
- \`SupplierCreditNote\` y \`SupplierCreditAllocation\`: notas de crédito y aplicación de saldos.
- \`FinancialAuditEvent\`: eventos financieros con usuario, sin almacenar CLABE ni números de cuenta.
- \`AccountsPayableReminderJob\`: vencidos, hoy y próximos a vencer (1/3/7 días), con prevención de envíos duplicados.
- \`AccountsPayable::Reconcile\`: conciliación y resumen por moneda.

## Preparación

Configurar tres secretos duraderos antes de capturar bancos, vía credenciales Rails o variables de entorno:

\`\`\`text
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
\`\`\`

No rotar las claves sin un plan de migración; se necesitan para descifrar información existente. Los tests usan claves no productivas aisladas.

Ejecutar migraciones y semillas de permisos:

\`\`\`bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate
docker compose -f docker-compose.dev.yml exec web bin/rails db:seed
\`\`\`

En producción, Solid Queue programa automáticamente `AccountsPayableReminderJob` a las **14:00 UTC (08:00 Ciudad de México)** mediante `config/recurring.yml`. Requiere que el supervisor de Solid Queue esté activo en el despliegue.

Para desarrollo con Sidekiq, o ejecuciones manuales, usar:

\`\`\`bash
bin/rails accounts_payable:reminders
\`\`\`

No programar adicionalmente el mismo job con cron en producción cuando Solid Queue recurring esté activo; la tabla de entregas evita duplicados, pero es preferible una sola programación.

## Reglas de operación

- La recepción de mercancía no genera automáticamente una deuda. La deuda se origina únicamente al confirmar una factura.
- Las facturas de servicios pueden registrarse sin orden. Para comparar recepciones se requiere una orden vinculada.
- Los importes se liquidan en la misma moneda de la factura. Las conciliaciones nunca suman distintas monedas.
- La cancelación de facturas con movimientos previos se rechaza.
- Los archivos CFDI se validan estructuralmente; para verificar la vigencia del sello o el estatus actual en SAT se necesita un servicio de validación adicional.
- Los usuarios requieren permisos específicos \`accounts_payable.*\`; revelar cuentas requiere \`accounts_payable.banks.reveal\`.
- Se debe utilizar HTTPS, almacenamiento privado, controles de acceso a documentos y políticas de retención fiscales.
