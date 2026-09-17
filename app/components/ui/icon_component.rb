# frozen_string_literal: true

module Ui
  class IconComponent < ViewComponent::Base
    VARIANTS = %i[
      outline
      solid
      mini
      micro
    ].freeze

    SIZES = %i[
      xs
      sm
      md
      lg
      xl
      xxl
    ].freeze

    COLORS = %i[
      inherit
      primary
      secondary
      success
      warning
      danger
      white
      gray
    ].freeze

    def initialize(
      name:,
      variant: :outline,
      size: :md,
      color: :inherit,
      css_class: nil
    )
      @name = name
      @variant = variant
      @size = size
      @color = color
      @css_class = css_class

      validate!
    end

    private

    attr_reader :name,
                :variant,
                :size,
                :color,
                :css_class

    def validate!
      raise ArgumentError, 'Variant inválido' unless VARIANTS.include?(variant)
      raise ArgumentError, 'Size inválido' unless SIZES.include?(size)
      raise ArgumentError, 'Color inválido' unless COLORS.include?(color)
    end

    def icon_name
      name.to_s.tr('_', '-')
    end

    def classes
      class_names(
        size_classes,
        color_classes,
        css_class
      )
    end

    def size_classes
      {
        xs: 'h-3 w-3',
        sm: 'h-4 w-4',
        md: 'h-5 w-5',
        lg: 'h-6 w-6',
        xl: 'h-8 w-8',
        xxl: 'h-10 w-10'
      }.fetch(size)
    end

    def color_classes
      {
        inherit: nil,
        primary: 'text-blue-600',
        secondary: 'text-slate-700',
        success: 'text-emerald-600',
        warning: 'text-amber-500',
        danger: 'text-red-600',
        white: 'text-white',
        gray: 'text-slate-400'
      }.fetch(color)
    end
  end
end