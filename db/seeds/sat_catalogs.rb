# frozen_string_literal: true

require_relative 'sat_catalog_core_data'
require_relative 'sat_catalog_extra_data'

module SatCatalogSeeds
  def self.seed!
    seed_basic_entries
    seed_regimes
    seed_months
    seed_banks
    seed_currencies
    seed_units
    seed_countries
  end

  def self.seed_basic_entries
    SatCatalogCoreData::CORE.each do |model, entries|
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
  end

  def self.insert_if_missing(model, key, **attributes)
    record = model.with_deleted.find_by(key)
    return record if record

    model.create!(key.merge(attributes))
  end

  def self.seed_regimes
    SeedConsole.track('Regímenes fiscales SAT', SatFiscalRegime) do
      SatCatalogExtraData::FISCAL_REGIMES.each do |code, description, person_type|
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
        description = SatCatalogExtraData::MONTH_BIMESTERS[number] || Date::MONTHNAMES.fetch(number)
        insert_if_missing(SatMonth, { code: format('%02d', number) },
                          description:, month_number: number, status: true)
      end
    end
  end

  def self.seed_banks
    SeedConsole.track('Bancos SAT', SatBank) do
      SatCatalogExtraData::BANKS.each { |code, name| insert_if_missing(SatBank, { code: }, name:, status: true) }
    end
  end

  def self.seed_currencies
    SeedConsole.track('Monedas SAT', SatCurrency) do
      SatCatalogExtraData::CURRENCIES.each do |code, (description, decimals, symbol)|
        insert_if_missing(SatCurrency, { code: }, description:, decimals:, symbol:)
      end
    end
  end

  def self.seed_units
    SeedConsole.track('Unidades SAT', SatUnitKey) do
      SatCatalogExtraData::UNITS.each do |code, (description, symbol)|
        insert_if_missing(SatUnitKey, { code: }, description:, symbol:)
      end
    end
  end

  def self.seed_countries
    SeedConsole.track('Países SAT de referencia', SatCountry) do
      SatCatalogExtraData::COUNTRIES.each { |code, description| insert_if_missing(SatCountry, { code: }, description:) }
    end
  end
end
