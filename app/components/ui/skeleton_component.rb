# frozen_string_literal: true

module Ui
  # Non-interactive placeholders for genuinely asynchronous regions.
  # A single configurable component keeps the loading structure consistent.
  class SkeletonComponent < ViewComponent::Base
    VARIANTS = %i[table card dashboard form detail list].freeze

    attr_reader :variant, :rows, :columns

    def initialize(variant:, rows: 5, columns: 5)
      super()
      @variant = variant.to_sym
      @rows = Integer(rows)
      @columns = Integer(columns)

      raise ArgumentError, 'Unknown skeleton variant' unless VARIANTS.include?(@variant)
      raise ArgumentError, 'Rows must be between 1 and 12' unless (1..12).cover?(@rows)
      raise ArgumentError, 'Columns must be between 1 and 8' unless (1..8).cover?(@columns)
    end
  end
end
