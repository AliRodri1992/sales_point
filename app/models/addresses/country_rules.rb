# frozen_string_literal: true

module Addresses
  class CountryRules
    NO_POSTAL_CODE = %w[AE HK MO QA].freeze
    STATE_REQUIRED = %w[MX US CA AU BR IN].freeze
    POSTAL_FORMATS = {
      'MX' => /\A\d{5}\z/,
      'US' => /\A\d{5}(?:-\d{4})?\z/,
      'CA' => /\A[A-Z]\d[A-Z][ ]?\d[A-Z]\d\z/i,
      'GB' => /\A(?:GIR[ ]?0AA|(?:[A-Z]{1,2}\d[A-Z\d]?[ ]?\d[A-Z]{2}))\z/i,
      'KR' => /\A\d{5}\z/,
      'JP' => /\A\d{3}-?\d{4}\z/,
      'AU' => /\A\d{4}\z/,
      'BR' => /\A\d{5}-?\d{3}\z/,
      'DE' => /\A\d{5}\z/,
      'FR' => /\A\d{5}\z/,
      'IN' => /\A\d{6}\z/
    }.freeze
    DEFAULT_POSTAL_FORMAT = /\A[A-Z\d][A-Z\d -]{0,9}\z/i

    def initialize(country_code)
      @country_code = country_code.to_s.upcase
    end

    def mexico? = @country_code == 'MX'
    def exterior_required? = mexico?
    def neighborhood_required? = mexico?
    def state_required? = STATE_REQUIRED.include?(@country_code)
    def postal_required? = !NO_POSTAL_CODE.include?(@country_code)

    def valid_postal_code?(value)
      (POSTAL_FORMATS[@country_code] || DEFAULT_POSTAL_FORMAT).match?(value.to_s.strip)
    end
  end
end
