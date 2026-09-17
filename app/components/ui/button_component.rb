# frozen_string_literal: true

module Ui
  class ButtonComponent < ViewComponent::Base
    VARIANTS = %i[
      primary
      secondary
      success
      danger
      outline
      ghost
    ].freeze

    SIZES = %i[
      xs
      sm
      md
      lg
      xl
    ].freeze

    def initialize(
      text:,
      href: nil,
      variant: :primary,
      size: :md,
      full_width: false,
      disabled: false,
      icon: nil,
      icon_position: :left
    )
      @text = text
      @href = href
      @variant = variant
      @size = size
      @full_width = full_width
      @disabled = disabled
      @icon = icon
      @icon_position = icon_position

      validate!
    end

    private

    attr_reader :text,
                :href,
                :variant,
                :size,
                :full_width,
                :disabled,
                :icon,
                :icon_position

    def validate!
      raise ArgumentError, 'Variant inválido' unless VARIANTS.include?(variant)
      raise ArgumentError, 'Size inválido' unless SIZES.include?(size)
    end

    def icon_name
      icon.to_s.tr('_', '-')
    end

    def classes
      class_names(
        'inline-flex items-center justify-center gap-2 font-semibold transition duration-300 focus:outline-none focus:ring-4',
        size_classes,
        variant_classes,
        full_width ? 'w-full' : nil,
        disabled ? 'opacity-50 cursor-not-allowed' : nil
      )
    end

    def size_classes
      {
        xs: 'px-3 py-1.5 text-xs rounded-lg',
        sm: 'px-4 py-2 text-sm rounded-xl',
        md: 'px-6 py-3 text-base rounded-xl',
        lg: 'px-8 py-4 text-lg rounded-2xl',
        xl: 'px-10 py-5 text-xl rounded-2xl'
      }.fetch(size)
    end

    def variant_classes
      {
        primary: 'bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-300',
        secondary: 'bg-slate-900 hover:bg-slate-800 text-white focus:ring-slate-300',
        success: 'bg-emerald-600 hover:bg-emerald-700 text-white focus:ring-emerald-300',
        danger: 'bg-red-600 hover:bg-red-700 text-white focus:ring-red-300',
        outline: 'border border-slate-300 bg-white text-slate-700 hover:bg-slate-50',
        ghost: 'text-slate-700 hover:bg-slate-100'
      }.fetch(variant)
    end
  end
end