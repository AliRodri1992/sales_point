# frozen_string_literal: true

module Ui
  class BadgeComponent < ViewComponent::Base
    COLORS = %i[
      primary
      success
      warning
      danger
      gray
    ].freeze

    def initialize(
      text:,
      color: :primary
    )
      @text = text
      @color = color

      raise ArgumentError unless COLORS.include?(color)
    end

    private

    attr_reader :text,
                :color

    def classes
      class_names(
        'inline-flex items-center rounded-full px-4 py-1 text-sm font-semibold',
        color_classes
      )
    end

    def color_classes
      {
        primary: 'bg-blue-100 text-blue-700',
        success: 'bg-emerald-100 text-emerald-700',
        warning: 'bg-amber-100 text-amber-700',
        danger: 'bg-red-100 text-red-700',
        gray: 'bg-slate-100 text-slate-700'
      }.fetch(color)
    end
  end
end