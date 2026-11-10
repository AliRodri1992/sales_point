# frozen_string_literal: true

# Common, tenant-owned units for the Delta POS demonstration organization.
# SAT codes are a separate fiscal catalog and never imply a Product association.
module UnitMeasureExamples
  DATA = [
    { code: 'PZA', name: 'Pieza', abbreviation: 'pza', sat: 'H87', precision: 0,
      description: 'Artículo individual de venta.' },
    { code: 'CAJA', name: 'Caja', abbreviation: 'caja', sat: 'XBX', precision: 0,
      description: 'Presentación comercial por caja.' },
    { code: 'PAQUETE', name: 'Paquete', abbreviation: 'paq', sat: 'XPK', precision: 0,
      description: 'Artículos agrupados en un paquete.' },
    { code: 'DOCENA', name: 'Docena', abbreviation: 'doc', sat: 'DPC', precision: 0,
      description: 'Conjunto de doce piezas.' },
    { code: 'PAR', name: 'Par', abbreviation: 'par', sat: 'PR', precision: 0,
      description: 'Conjunto de dos piezas.' },
    { code: 'KIT', name: 'Kit', abbreviation: 'kit', sat: 'KT', precision: 0,
      description: 'Conjunto de artículos vendido como kit.' },
    { code: 'CONJUNTO', name: 'Conjunto', abbreviation: 'set', sat: 'SET', precision: 0,
      description: 'Artículos agrupados en un conjunto.' },
    { code: 'LOTE', name: 'Lote', abbreviation: 'lote', sat: 'XLT', precision: 0,
      description: 'Artículos comercializados por lote.' },
    { code: 'KILO', name: 'Kilogramo', abbreviation: 'kg', sat: 'KGM', precision: 3,
      description: 'Masa medida en kilogramos.' },
    { code: 'GRAMO', name: 'Gramo', abbreviation: 'g', sat: 'GRM', precision: 2,
      description: 'Masa medida en gramos.' },
    { code: 'MILIGRAMO', name: 'Miligramo', abbreviation: 'mg', sat: 'MGM', precision: 3,
      description: 'Masa medida en miligramos.' },
    { code: 'TONELADA', name: 'Tonelada', abbreviation: 't', sat: 'TNE', precision: 3,
      description: 'Masa medida en toneladas métricas.' },
    { code: 'LITRO', name: 'Litro', abbreviation: 'L', sat: 'LTR', precision: 3,
      description: 'Volumen medido en litros.' },
    { code: 'MILILITRO', name: 'Mililitro', abbreviation: 'mL', sat: 'MLT', precision: 2,
      description: 'Volumen medido en mililitros.' },
    { code: 'METRO', name: 'Metro', abbreviation: 'm', sat: 'MTR', precision: 3,
      description: 'Longitud medida en metros.' },
    { code: 'CENTIMETRO', name: 'Centímetro', abbreviation: 'cm', sat: 'CMT', precision: 2,
      description: 'Longitud medida en centímetros.' },
    { code: 'METRO2', name: 'Metro cuadrado', abbreviation: 'm²', sat: 'MTK', precision: 2,
      description: 'Superficie medida en metros cuadrados.' },
    { code: 'METRO3', name: 'Metro cúbico', abbreviation: 'm³', sat: 'MTQ', precision: 3,
      description: 'Volumen medido en metros cúbicos.' },
    { code: 'HORA', name: 'Hora', abbreviation: 'h', sat: 'HUR', precision: 2,
      description: 'Servicio o tiempo medido por hora.' },
    { code: 'MINUTO', name: 'Minuto', abbreviation: 'min', sat: 'MIN', precision: 0,
      description: 'Servicio o tiempo medido por minuto.' },
    { code: 'DIA', name: 'Día', abbreviation: 'día', sat: 'DAY', precision: 0,
      description: 'Servicio o tiempo medido por día.' },
    { code: 'SEMANA', name: 'Semana', abbreviation: 'sem', sat: 'WEE', precision: 0,
      description: 'Servicio o tiempo medido por semana.' },
    { code: 'MES', name: 'Mes', abbreviation: 'mes', sat: 'MON', precision: 0,
      description: 'Servicio o tiempo medido por mes.' },
    { code: 'ANIO', name: 'Año', abbreviation: 'año', sat: 'ANN', precision: 0,
      description: 'Servicio o tiempo medido por año.' },
    { code: 'SERVICIO', name: 'Servicio', abbreviation: 'serv', sat: 'E48', precision: 0,
      description: 'Servicio facturado por unidad.' },
    { code: 'ACTIVIDAD', name: 'Actividad', abbreviation: 'act', sat: 'ACT', precision: 0,
      description: 'Actividad realizada.' },
    { code: 'VIAJE', name: 'Viaje', abbreviation: 'viaje', sat: 'E54', precision: 0,
      description: 'Servicio realizado por viaje.' },
    { code: 'KWH', name: 'Kilowatt-hora', abbreviation: 'kWh', sat: 'KWH', precision: 3,
      description: 'Consumo de energía medido en kilowatt-hora.' }
  ].freeze

  def self.seed!(organization:)
    sat_codes = DATA.map { |entry| entry.fetch(:sat) }
    sat_keys = SatUnitKey.current.where(code: sat_codes).index_by(&:code)
    existing_codes = UnitOfMeasure.with_deleted.where(organization:).pluck(:code).to_set(&:upcase)
    missing = []

    UnitOfMeasure.transaction do
      DATA.each { |entry| seed_unit!(organization:, entry:, sat_keys:, existing_codes:, missing:) }
    end
    report_missing_sat_keys(missing)
  end

  def self.seed_unit!(organization:, entry:, sat_keys:, existing_codes:, missing:)
    code = entry.fetch(:code)
    return if existing_codes.include?(code)

    sat_key = sat_keys[entry.fetch(:sat)]
    unless sat_key
      missing << entry.fetch(:sat)
      return
    end

    UnitOfMeasure.create!(
      organization:, code:, sat_unit_key: sat_key, name: entry.fetch(:name),
      abbreviation: entry.fetch(:abbreviation), description: entry.fetch(:description),
      decimal_precision: entry.fetch(:precision), status: :active
    )
    existing_codes.add(code)
  end

  def self.report_missing_sat_keys(missing)
    return if missing.empty?

    codes = missing.uniq.sort.join(', ')
    $stdout.puts "[SEEDS][UNIDADES][ADVERTENCIA] Claves SAT no vigentes o ausentes: #{codes}"
  end

  private_class_method :seed_unit!, :report_missing_sat_keys
end
