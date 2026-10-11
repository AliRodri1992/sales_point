# frozen_string_literal: true

class CountryCurrency < ApplicationRecord
  belongs_to :country
  belongs_to :currency

  validates :currency_id, uniqueness: { scope: :country_id }
  validate :primary_must_be_active
  validate :only_one_primary_currency

  private

  def only_one_primary_currency
    return unless is_primary? && country_id.present?

    existing = self.class.where(country_id:, is_primary: true).where.not(id: id).exists?
    errors.add(:is_primary, :taken) if existing
  end

  def primary_must_be_active
    errors.add(:is_primary, :invalid) if is_primary? && !active?
  end
end
