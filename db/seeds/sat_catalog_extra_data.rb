# frozen_string_literal: true

# Supporting fiscal and financial reference keys.
module SatCatalogExtraData
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

  # Frequent c_ClaveUnidad references only; full official datasets load from CSV.
  # Keep existing historical/manual descriptions untouched when seeding.
  UNITS = {
    'ACT' => ['Actividad', nil],
    'ANN' => ['Año', nil],
    'C62' => ['Uno', nil],
    'CMT' => %w[Centímetro cm],
    'DAY' => ['Día', nil],
    'DPC' => ['Docenas de piezas', nil],
    'E48' => ['Unidad de servicio', nil],
    'E51' => ['Trabajo', nil],
    'E54' => ['Viaje', nil],
    'EA' => ['Elemento', nil],
    'GRM' => %w[Gramo g],
    'H87' => %w[Pieza pza],
    'HUR' => %w[Hora h],
    'KGM' => %w[Kilogramo kg],
    'KT' => ['Kit', nil],
    'KWH' => %w[Kilowatt-hora kWh],
    'LTR' => %w[Litro L],
    'MGM' => %w[Miligramo mg],
    'MIN' => %w[Minuto min],
    'MLT' => %w[Mililitro mL],
    'MON' => ['Mes', nil],
    'MTK' => ['Metro cuadrado', 'm²'],
    'MTQ' => ['Metro cúbico', 'm³'],
    'MTR' => %w[Metro m],
    'PR' => ['Par', nil],
    'SET' => ['Conjunto', nil],
    'TNE' => ['Tonelada (tonelada métrica)', 't'],
    'WEE' => ['Semana', nil],
    'XBX' => ['Caja', nil],
    'XLT' => ['Lote', nil],
    'XPK' => ['Paquete', nil]
  }.freeze

  COUNTRIES = {
    'MEX' => 'México', 'USA' => 'Estados Unidos', 'CAN' => 'Canadá',
    'KOR' => 'Corea del Sur'
  }.freeze
end
