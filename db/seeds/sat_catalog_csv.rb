# frozen_string_literal: true

require 'csv'
require 'json'
require 'set'

# Imports normalized exports of SAT CFDI 4.0 catalogs, without inventing
# entries or attempting a network download during db:seed.
module SatCatalogCsv
  CATALOGS = {
    'sat_banks' => [SatBank, %w[code]],
    'sat_cfdi_uses' => [SatCfdiUse, %w[code]],
    'sat_countries' => [SatCountry, %w[code]],
    'sat_currencies' => [SatCurrency, %w[code]],
    'sat_customs_offices' => [SatCustomsOffice, %w[code]],
    'sat_customs_patents' => [SatCustomsPatent, %w[code]],
    'sat_customs_pediment_numbers' => [SatCustomsPedimentNumber, %w[code]],
    'sat_export_types' => [SatExportType, %w[code]],
    'sat_factor_types' => [SatFactorType, %w[code]],
    'sat_fiscal_regimes' => [SatFiscalRegime, %w[code]],
    'sat_localities' => [SatLocality, %w[state_code code]],
    'sat_months' => [SatMonth, %w[code]],
    'sat_municipalities' => [SatMunicipality, %w[state_code code]],
    'sat_neighborhoods' => [SatNeighborhood, %w[postal_code code]],
    'sat_payment_method_types' => [SatPaymentMethodType, %w[code]],
    'sat_payment_methods' => [SatPaymentMethod, %w[code]],
    'sat_periodicities' => [SatPeriodicity, %w[code]],
    'sat_postal_codes' => [SatPostalCode, %w[code]],
    'sat_product_service_keys' => [SatProductServiceKey, %w[code]],
    'sat_relationship_types' => [SatRelationshipType, %w[code]],
    'sat_states' => [SatState, %w[country_code code]],
    'sat_tax_codes' => [SatTaxCode, %w[code]],
    'sat_tax_objects' => [SatTaxObject, %w[code]],
    'sat_tax_rates' => [SatTaxRate, %w[catalog_key]],
    'sat_taxes' => [SatTax, %w[code]],
    'sat_unit_keys' => [SatUnitKey, %w[code]],
    'sat_voucher_types' => [SatVoucherType, %w[code]]
  }.freeze

  BATCH_SIZE = 500
  RESERVED = %w[id created_at updated_at deleted_at].freeze

  def self.seed!(directory: ENV.fetch('SAT_CATALOGS_DIR', Rails.root.join('db/seeds/data/sat').to_s))
    missing = []
    imported = 0

    CATALOGS.each do |table, (model, keys)|
      source = File.join(directory, "#{table}.csv")
      unless File.file?(source)
        missing << table
        next
      end

      imported += import_file(source, model, keys)
    end

    $stdout.puts "[SEEDS][SAT][OK] #{imported} registros oficiales adicionales importados"
    return if missing.empty?

    $stdout.puts "[SEEDS][SAT][PENDIENTE] #{missing.size} catálogos sin CSV completo: #{missing.join(', ')}"
    $stdout.puts '[SEEDS][SAT][INFO] Consultar db/seeds/data/sat/README.md; las claves básicas no sustituyen al SAT.'
    raise "Faltan #{missing.size} catálogos SAT oficiales" if ENV['SAT_CATALOGS_REQUIRED'] == 'true'
  end

  def self.import_file(path, model, key_fields)
    rows = CSV.foreach(path, headers: true, encoding: 'bom|utf-8')
    headers = rows.first&.headers
    raise ArgumentError, "#{path}: CSV sin encabezados ni registros" if headers.nil?

    allowed = model.column_names - RESERVED
    unknown = headers - allowed
    required = key_fields + required_columns(model)
    missing = required - headers
    raise ArgumentError, "#{path}: columnas no admitidas: #{unknown.join(', ')}" if unknown.any?
    raise ArgumentError, "#{path}: faltan columnas: #{missing.join(', ')}" if missing.any?
    raise ArgumentError, "#{path}: encabezados duplicados" if headers.uniq.size != headers.size

    seen = model.with_deleted.pluck(*key_fields).map { |value| Array(value) }.to_set
    count = 0
    buffer = []

    model.transaction do
      rows.each.with_index(2) do |row, line_number|
        attributes = parse_row(model, row)
        key = key_fields.map { |field| attributes.fetch(field) }
        raise ArgumentError, "#{path}: clave vacía (fila #{line_number})" if key.any?(&:blank?)
        next unless seen.add?(key)

        buffer << attributes
        next if buffer.length < BATCH_SIZE

        model.insert_all(buffer, returning: false)
        count += buffer.length
        buffer.clear
      end
      if buffer.any?
        model.insert_all(buffer, returning: false)
        count += buffer.length
      end
    end
    $stdout.puts "[SEEDS][SAT][OK] #{model.table_name}: #{count} filas añadidas"
    count
  rescue StandardError => e
    raise e.class, "#{path}: #{e.message}", e.backtrace
  end

  def self.parse_row(model, row)
    row.to_h.to_h do |column, value|
      parsed = if value.nil? || value.strip.empty?
                 nil
               elsif model.columns_hash.fetch(column).array
                 JSON.parse(value)
               else
                 model.type_for_attribute(column).cast(value.strip)
               end
      [column, parsed]
    end
  end

  def self.required_columns(model)
    model.columns.filter_map do |column|
      next if (RESERVED + %w[status]).include?(column.name)
      next if column.null || !column.default.nil?

      column.name
    end
  end

  private_class_method :parse_row, :required_columns
end
