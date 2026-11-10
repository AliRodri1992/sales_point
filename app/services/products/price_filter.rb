# frozen_string_literal: true

module Products
  class PriceFilter
    def self.parse(value)
      return if value.blank?

      number = BigDecimal(value.to_s, exception: false)
      number if number&.finite? && number >= 0
    end

    def self.inverted?(minimum, maximum)
      min = parse(minimum)
      max = parse(maximum)
      min && max && min > max
    end
  end
end
