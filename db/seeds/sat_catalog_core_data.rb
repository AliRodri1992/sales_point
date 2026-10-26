# frozen_string_literal: true

# Frequently used baseline keys, not a replacement for the published SAT workbook.
module SatCatalogCoreData
  CORE = {
    SatVoucherType => {
      'I' => 'Ingreso', 'E' => 'Egreso', 'T' => 'Traslado',
      'N' => 'Nómina', 'P' => 'Pago'
    },
    SatFactorType => {
      'Tasa' => 'Tasa', 'Cuota' => 'Cuota', 'Exento' => 'Exento'
    },
    SatTaxObject => {
      '01' => 'No objeto de impuesto', '02' => 'Sí objeto de impuesto',
      '03' => 'Sí objeto del impuesto y no obligado al desglose'
    },
    SatTaxCode => {
      '001' => 'ISR', '002' => 'IVA', '003' => 'IEPS'
    },
    SatExportType => {
      '01' => 'No aplica', '02' => 'Definitiva', '03' => 'Temporal'
    },
    SatPeriodicity => {
      '01' => 'Diario', '02' => 'Semanal', '03' => 'Quincenal',
      '04' => 'Mensual', '05' => 'Bimestral'
    },
    SatRelationshipType => {
      '01' => 'Nota de crédito de los documentos relacionados',
      '02' => 'Nota de débito de los documentos relacionados',
      '03' => 'Devolución de mercancía sobre facturas o traslados previos',
      '04' => 'Sustitución de los CFDI previos',
      '05' => 'Traslados de mercancías facturados previamente',
      '06' => 'Factura generada por los traslados previos',
      '07' => 'CFDI por aplicación de anticipo'
    },
    SatPaymentMethodType => {
      'PUE' => 'Pago en una sola exhibición',
      'PPD' => 'Pago en parcialidades o diferido'
    },
    SatPaymentMethod => {
      '01' => 'Efectivo', '02' => 'Cheque nominativo',
      '03' => 'Transferencia electrónica de fondos',
      '04' => 'Tarjeta de crédito', '05' => 'Monedero electrónico',
      '06' => 'Dinero electrónico', '08' => 'Vales de despensa',
      '12' => 'Dación en pago', '13' => 'Pago por subrogación',
      '14' => 'Pago por consignación', '15' => 'Condonación',
      '17' => 'Compensación', '23' => 'Novación', '24' => 'Confusión',
      '25' => 'Remisión de deuda', '26' => 'Prescripción o caducidad',
      '27' => 'A satisfacción del acreedor', '28' => 'Tarjeta de débito',
      '29' => 'Tarjeta de servicios', '30' => 'Aplicación de anticipos',
      '31' => 'Intermediario pagos', '99' => 'Por definir'
    },
    SatCfdiUse => {
      'G01' => 'Adquisición de mercancías',
      'G02' => 'Devoluciones, descuentos o bonificaciones',
      'G03' => 'Gastos en general',
      'I01' => 'Construcciones',
      'I02' => 'Mobiliario y equipo de oficina por inversiones',
      'I03' => 'Equipo de transporte',
      'I04' => 'Equipo de cómputo y accesorios',
      'D01' => 'Honorarios médicos, dentales y gastos hospitalarios',
      'D10' => 'Pagos por servicios educativos (colegiaturas)',
      'S01' => 'Sin efectos fiscales',
      'CP01' => 'Pagos',
      'CN01' => 'Nómina'
    }
  }.freeze

end
