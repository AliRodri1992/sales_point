# frozen_string_literal: true

require 'csv'
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
    missing, available = CATALOGS.partition { |table, _| !File.file?(File.join(directory, "#{table}.csv")) }
    count = available.sum do |table, (model, keys)|
      import_file(File.join(directory, "#{table}.csv"), model, keys)
    end
    report_missing(missing.map(&:first), count)
    nil
  end

  def self.report_missing(missing, imported)
    $stdout.puts "[SEEDS][SAT][OK] #{imported} registros oficiales adicionales importados"
    return if missing.empty?

    $stdout.puts "[SEEDS][SAT][PENDIENTE] #{missing.size} catálogos sin CSV completo: #{missing.join(', ')}"
    $stdout.puts '[SEEDS][SAT][INFO] Consultar db/seeds/data/sat/README.md; las claves básicas no sustituyen al SAT.'
    raise "Faltan #{missing.size} catálogos SAT oficiales" if ENV['SAT_CATALOGS_REQUIRED'] == 'true'
  end

  def self.import_file(path, model, keys)
    rows = CSV.foreach(path, headers: true, encoding: 'bom|utf-8')
    validate_headers!(rows.first&.headers, model, keys, path)
    known = model.with_deleted.pluck(*keys).to_set { |values| Array(values) }

    count = model.transaction { insert_missing_rows(rows, model, keys, known, path) }
    $stdout.puts "[SEEDS][SAT][OK] #{model.table_name}: #{count} filas añadidas"
    count
  rescue StandardError => e
    raise e.class, "#{path}: #{e.message}", e.backtrace
  end

  def self.validate_headers!(headers, model, keys, path)
    raise ArgumentError, "#{path}: CSV sin encabezados ni registros" unless headers
    raise ArgumentError, "#{path}: encabezados duplicados" if headers.uniq.size != headers.size

    unknown = headers - (model.column_names - RESERVED)
    missing = (keys + required_columns(model)) - headers
    raise ArgumentError, "#{path}: columnas no admitidas: #{unknown.join(', ')}" if unknown.any?
    raise ArgumentError, "#{path}: faltan columnas: #{missing.join(', ')}" if missing.any?
  end

  def self.insert_missing_rows(rows, model, keys, known, path)
    batch = []
    count = 0
    rows.each.with_index(2) do |row, line|
      attributes = parse_row(model, row)
      key = keys.map { |field| attributes.fetch(field) }
      raise ArgumentError, "#{path}: clave vacía (fila #{line})" if key.any?(&:blank?)
      next unless known.add?(key)

      batch << attributes
      count += flush_batch(model, batch) if batch.length == BATCH_SIZE
    end
    count + flush_batch(model, batch)
  end

  def self.flush_batch(model, batch)
    count = batch.length
    return 0 if count.zero?

    # SAT source is normalized; DB types and constraints validate each row.
    # Bulk loading large postal/product/pediment catalogs must avoid N queries.
    # rubocop:disable Rails/SkipsModelValidations
    model.insert_all(batch, returning: false)
    # rubocop:enable Rails/SkipsModelValidations
    batch.clear
    count
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

  private_class_method :parse_row, :required_columns, :flush_batch,
                       :validate_headers!, :insert_missing_rows, :report_missing
end
