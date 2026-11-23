# frozen_string_literal: true

module CommercialCurrency
  extend ActiveSupport::Concern

  included do
    before_validation :default_commercial_currency, on: :create
    normalizes :currency, with: ->(value) { value.strip.upcase }
    validates :currency, inclusion: { in: :commercial_currency_codes }
    validate :preserve_currency, on: :update
  end

  private

  def default_commercial_currency
    return if currency_came_from_user? || !organization

    base = organization.organization_settings.active_records.first&.base_currency
    self.currency = base.code if base
  end

  def commercial_currency_codes
    codes = Currency.active.pluck(:code)
    codes << currency_in_database if persisted?
    codes
  end

  def preserve_currency
    errors.add(:currency, I18n.t('admin.catalog_design.currency_fixed')) if will_save_change_to_currency?
  end
end
