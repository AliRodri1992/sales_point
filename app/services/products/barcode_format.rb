# frozen_string_literal: true

module Products
  class BarcodeFormat
    LENGTHS = { 'ean13' => 13, 'ean8' => 8, 'upca' => 12 }.freeze

    def self.valid?(value, symbology)
      return value.match?(/\A[\x20-\x7e]+\z/) if symbology == 'code128'
      return value.present? if symbology == 'qr'

      valid_numeric?(value, symbology)
    end

    def self.valid_numeric?(value, symbology)
      return false unless value.match?(/\A[0-9]+\z/) && value.length == LENGTHS[symbology]

      digits = value.chars.map(&:to_i)
      sum = digits[0...-1].reverse.each_with_index.sum { |digit, index| digit * (index.even? ? 3 : 1) }
      (10 - (sum % 10)) % 10 == digits.last
    end
    private_class_method :valid_numeric?
  end
end
