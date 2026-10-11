# frozen_string_literal: true

class CountryCurrency < ApplicationRecord
  belongs_to :country
  belongs_to :currency

  validates :currency_id, uniqueness: { scope: :country_id }
  validate :primary_must_be_active

  private

  def primary_must_be_active
    errors.add(:is_primary, :invalid) if is_primary? && !active?
  end
end
