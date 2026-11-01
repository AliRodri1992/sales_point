# frozen_string_literal: true

module CurrencySeeds
  DATA = [
    { code: 'MXN', name: 'Mexican Peso', numeric_code: '484', symbol: '$', decimal_places: 2 },
    { code: 'USD', name: 'US Dollar', numeric_code: '840', symbol: 'US$', decimal_places: 2 },
    { code: 'KRW', name: 'South Korean Won', numeric_code: '410', symbol: '₩', decimal_places: 0 }
  ].freeze

  def self.seed!
    DATA.each do |attributes|
      currency = Currency.with_deleted.find_or_initialize_by(code: attributes.fetch(:code))
      currency.restore! if currency.persisted? && currency.deleted?
      currency.assign_attributes(attributes.merge(active: true))
      currency.save!
    end
  end
end
