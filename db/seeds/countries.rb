# frozen_string_literal: true

require 'json'

module CountrySeeds
  DATA_PATH = Rails.root.join('db/seeds/data/countries.json')

  def self.seed!
    records = JSON.parse(File.read(DATA_PATH))
    records.each_with_index do |attributes, position|
      country = Country.with_deleted.find_or_initialize_by(iso_alpha2: attributes.fetch('iso_alpha2'))
      country.restore! if country.persisted? && country.deleted?
      country.assign_attributes(attributes.merge('active' => true, 'position' => position))
      country.save!
    end

    link_currency('MX', 'MXN')
    link_currency('US', 'USD')
    link_currency('KR', 'KRW')
  end

  def self.link_currency(country_code, currency_code)
    country = Country.find_by!(iso_alpha2: country_code)
    currency = Currency.find_by!(code: currency_code)
    link = CountryCurrency.find_or_initialize_by(country:, currency:)
    link.assign_attributes(active: true, is_primary: true)
    link.save!
  end

  private_class_method :link_currency
end
