# frozen_string_literal: true

# A small, usable baseline for CFDI 4.0. This is NOT the complete SAT workbook.
# Complete/historical catalogues are imported separately from verified CSV exports.
module SatCatalogSeeds
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

  FISCAL_REGIMES = [
    ['601', 'General de Ley Personas Morales', 'M'],
    ['603', 'Personas Morales con Fines no Lucrativos', 'M'],
    ['605', 'Sueldos y Salarios e Ingresos Asimilados a Salarios', 'F'],
    ['606', 'Arrendamiento', 'F'],
    ['608', 'Demás ingresos', 'F'],
    ['611', 'Ingresos por Dividendos (socios y accionistas)', 'F'],
    ['612', 'Personas Físicas con Actividades Empresariales y Profesionales', 'F'],
    ['614', 'Ingresos por intereses', 'F'],
    ['615', 'Obtención de premios', 'F'],
    ['616', 'Sin obligaciones fiscales', 'F'],
    ['620', 'Sociedades Cooperativas de Producción que optan por diferir sus ingresos', 'M'],
    ['621', 'Incorporación Fiscal', 'F'],
    ['622', 'Actividades Agrícolas, Ganaderas, Silvícolas y Pesqueras', 'F'],
    ['623', 'Opcional para Grupos de Sociedades', 'M'],
    ['624', 'Coordinados', 'M'],
    ['625', 'Actividades Empresariales con ingresos a través de Plataformas Tecnológicas', 'F'],
    ['626', 'Régimen Simplificado de Confianza', 'F']
  ].freeze

  MONTH_BIMESTERS = {
    13 => 'Enero-Febrero', 14 => 'Marzo-Abril', 15 => 'Mayo-Junio',
    16 => 'Julio-Agosto', 17 => 'Septiembre-Octubre', 18 => 'Noviembre-Diciembre'
  }.freeze

  BANKS = {
    '002' => 'Banco Nacional de México', '012' => 'BBVA México',
    '014' => 'Santander', '021' => 'HSBC', '030' => 'Banco del Bajío',
    '036' => 'Inbursa', '044' => 'Scotiabank', '058' => 'Banregio',
    '072' => 'Banorte', '127' => 'Banco Azteca',
    '137' => 'Bancoppel', '646' => 'Sistema de Transferencias y Pagos'
  }.freeze

  CURRENCIES = {
    'MXN' => ['Peso mexicano', 2, '$'],
    'USD' => ['Dólar estadounidense', 2, 'US$'],
    'EUR' => ['Euro', 2, '€'],
    'KRW' => ['Won surcoreano', 0, '₩']
  }.freeze

  UNITS = {
    'H87' => ['Pieza', 'pza'],
    'E48' => ['Unidad de servicio', nil],
    'KGM' => ['Kilogramo', 'kg'],
    'LTR' => ['Litro', 'L'],
    'ACT' => ['Actividad', nil],
    'XBX' => ['Caja', nil]
  }.freeze

  COUNTRIES = {
    'MEX' => 'México', 'USA' => 'Estados Unidos', 'CAN' => 'Canadá',
    'KOR' => 'Corea del Sur'
  }.freeze

  def self.seed!
    CORE.each do |model, entries|
      SeedConsole.track(model.table_name, model) do
        entries.each do |code, description|
          attributes = { description: }
          if model == SatCfdiUse
            attributes[:applies_to_individual] = true
            attributes[:applies_to_company] = !code.start_with?('D')
          end
          insert_if_missing(model, { code: }, **attributes)
        end
      end
    end
    seed_regimes
    seed_months
    seed_banks
    seed_currencies
    seed_units
    seed_countries
  end

  def self.insert_if_missing(model, key, **attributes)
    record = model.with_deleted.find_by(key)
    return record if record

    model.create!(key.merge(attributes))
  end

  def self.seed_regimes
    SeedConsole.track('Regímenes fiscales SAT', SatFiscalRegime) do
      FISCAL_REGIMES.each do |code, description, person_type|
        insert_if_missing(SatFiscalRegime, { code: },
                          description:, person_type:,
                          applies_to_individual: person_type == 'F',
                          applies_to_company: person_type == 'M' || code == '626')
      end
    end
  end

  def self.seed_months
    SeedConsole.track('Meses y bimestres SAT', SatMonth) do
      (1..18).each do |number|
        description = MONTH_BIMESTERS[number] || Date::MONTHNAMES.fetch(number)
        insert_if_missing(SatMonth, { code: format('%02d', number) },
                          description:, month_number: number, status: true)
      end
    end
  end

  def self.seed_banks
    SeedConsole.track('Bancos SAT', SatBank) do
      BANKS.each { |code, name| insert_if_missing(SatBank, { code: }, name:, status: true) }
    end
  end

  def self.seed_currencies
    SeedConsole.track('Monedas SAT', SatCurrency) do
      CURRENCIES.each do |code, (description, decimals, symbol)|
        insert_if_missing(SatCurrency, { code: }, description:, decimals:, symbol:)
      end
    end
  end

  def self.seed_units
    SeedConsole.track('Unidades SAT', SatUnitKey) do
      UNITS.each do |code, (description, symbol)|
        insert_if_missing(SatUnitKey, { code: }, description:, symbol:)
      end
    end
  end

  def self.seed_countries
    SeedConsole.track('Países SAT de referencia', SatCountry) do
      COUNTRIES.each { |code, description| insert_if_missing(SatCountry, { code: }, description:) }
    end
  end
end
