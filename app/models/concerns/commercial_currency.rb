# frozen_string_literal: true

module CommercialCurrency
  extend ActiveSupport::Concern

  included do
    normalizes :currency, with: ->(value) { value.strip.upcase }
    validates :currency, inclusion: { in: :commercial_currency_codes }
    validate :preserve_currency, on: :update
  end

  private

  def commercial_currency_codes
    codes = Currency.active.pluck(:code)
    codes << currency_in_database if persisted?
    codes
  end

  def preserve_currency
    errors.add(:currency, I18n.t('admin.catalog_design.currency_fixed')) if will_save_change_to_currency?
  end
end
