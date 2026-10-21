# frozen_string_literal: true

module SupplierFiscalRules
  extend ActiveSupport::Concern

  included do
    validates :rfc, length: { in: 12..13 },
                    format: { with: /\A[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}\z/i, message: :invalid_format },
                    presence: true, if: :mexican_tax_resident?
    validates :rfc, uniqueness: { scope: :organization_id, conditions: -> { where(deleted_at: nil) } },
                    allow_blank: true
    validates :foreign_tax_id, length: { maximum: 80 }, allow_blank: true
    validates :foreign_tax_id, presence: true, unless: :mexican_tax_resident?
    validate :rfc_must_match_person_type_and_date, if: :mexican_tax_resident?
    validate :sat_regime_matches_person_type
    before_validation :normalize_tax_identifiers
  end

  def mexican_tax_resident?
    fiscal = addresses.to_a.find do |address|
      address.purpose == 'fiscal' && address.primary? &&
        address.deleted_at.nil? && !address.marked_for_destruction?
    end
    fiscal.nil? || fiscal.country&.iso_alpha2 == 'MX'
  end

  private

  def normalize_tax_identifiers
    self.foreign_tax_id = foreign_tax_id.to_s.strip.presence
    return if mexican_tax_resident?

    self.rfc = nil
    self.sat_fiscal_regime = nil
  end

  def sat_regime_matches_person_type
    return unless mexican_tax_resident? && sat_fiscal_regime

    matching_type = person_type == 'individual' ? 'F' : 'M'
    valid_regime = sat_fiscal_regime.person_type == matching_type &&
                   sat_fiscal_regime.active? && sat_fiscal_regime.valid_for_date?
    errors.add(:sat_fiscal_regime, :invalid) unless valid_regime
  end

  def rfc_must_match_person_type_and_date
    return if rfc.blank? || !rfc.match?(/\A[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}\z/)

    prefix_length = rfc.length == 13 ? 4 : 3
    errors.add(:rfc, :person_type_mismatch) if rfc_person_type_mismatch?(prefix_length)
    errors.add(:rfc, :invalid_date) unless rfc_date_valid?(prefix_length)
  end

  def rfc_person_type_mismatch?(prefix_length)
    (person_type == 'individual' && prefix_length != 4) ||
      (person_type == 'company' && prefix_length != 3)
  end

  def rfc_date_valid?(prefix_length)
    date_digits = rfc[prefix_length, 6]
    month = date_digits[2, 2].to_i
    day = date_digits[4, 2].to_i
    year = date_digits[0, 2].to_i

    [2000 + year, 1900 + year].any? { |full_year| Date.valid_date?(full_year, month, day) }
  end
end
