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

end
