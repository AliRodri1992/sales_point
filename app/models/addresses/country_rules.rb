# frozen_string_literal: true

module Addresses
  class CountryRules
    NO_POSTAL_CODE = %w[AE HK MO QA].freeze
    STATE_REQUIRED = %w[MX US CA AU BR IN AR CO CL PE ZA].freeze
    POSTAL_FORMATS = {
      'MX' => /\A\d{5}\z/,
      'US' => /\A\d{5}(?:-\d{4})?\z/,
      'CA' => /\A[A-Z]\d[A-Z] ?\d[A-Z]\d\z/i,
      'GB' => /\A(?:GIR ?0AA|(?:[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}))\z/i,
      'KR' => /\A\d{5}\z/,
      'JP' => /\A\d{3}-?\d{4}\z/,
      'AU' => /\A\d{4}\z/,
      'BR' => /\A\d{5}-?\d{3}\z/,
      'DE' => /\A\d{5}\z/,
      'FR' => /\A\d{5}\z/,
      'IN' => /\A\d{6}\z/
    }.freeze
    DEFAULT_POSTAL_FORMAT = /\A[A-Z\d][A-Z\d -]{1,9}\z/i

    def initialize(country_code)
      @country_code = country_code.to_s.upcase
    end

    def mexico? = @country_code == 'MX'
    def exterior_required? = mexico?
    def neighborhood_applicable? = mexico?
    def neighborhood_required? = mexico?
    def state_required? = STATE_REQUIRED.include?(@country_code)
    def postal_required? = NO_POSTAL_CODE.exclude?(@country_code)

    def validate(address)
      required_fields.each do |field|
        address.errors.add(field, :blank) if address.public_send(field).blank?
      end
      return if address.postal_code.blank?

      address.errors.add(:postal_code, :invalid) unless valid_postal_code?(address.postal_code)
    end

    def required_fields
      fields = []
      fields << :exterior_number if exterior_required?
      fields << :neighborhood if neighborhood_required?
      fields << :state if state_required?
      fields << :postal_code if postal_required?
      fields
    end

    def valid_postal_code?(value)
      (POSTAL_FORMATS[@country_code] || DEFAULT_POSTAL_FORMAT).match?(value.to_s.strip)
    end
  end
end
