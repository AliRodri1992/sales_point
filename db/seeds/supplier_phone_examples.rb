# frozen_string_literal: true

module SupplierPhoneExamples
  module_function

  def number(index, kind)
    format(kind == 'landline' ? '552234%04d' : '551234%04d', index)
  end

  def attributes(supplier, index)
    %w[landline mobile].map do |kind|
      { number: number(index, kind), kind:, primary: true,
        country_code: 'MX', organization: supplier.organization }
    end
  end
end
