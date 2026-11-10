# frozen_string_literal: true

require 'set'

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
    sat_codes = DATA.map { |attributes| attributes.fetch(:sat) }.uniq
    sat_keys = SatUnitKey.current.where(code: sat_codes).index_by(&:code)
    existing = UnitOfMeasure.with_deleted.where(organization:).pluck(:code).map(&:upcase).to_set
    missing_sat_codes = Set.new

    UnitOfMeasure.transaction do
      DATA.each do |attributes|
        code = attributes.fetch(:code)
        next if existing.include?(code)

        fiscal_key = sat_keys[attributes.fetch(:sat)]
        unless fiscal_key
          missing_sat_codes.add(attributes.fetch(:sat))
          next
        end

        UnitOfMeasure.create!(
          organization:, sat_unit_key: fiscal_key, code:,
          name: attributes.fetch(:name), abbreviation: attributes.fetch(:abbreviation),
          description: attributes.fetch(:description), decimal_precision: attributes.fetch(:precision),
          status: :active
        )
        existing.add(code)
      end
    end

    return if missing_sat_codes.empty?

    codes = missing_sat_codes.to_a.sort.join(', ')
    $stdout.puts "[SEEDS][UNIDADES][ADVERTENCIA] Claves SAT no vigentes o ausentes: #{codes}"
  end
end
