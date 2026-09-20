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

    def initialize(attributes)
      super()

      @text = attributes.fetch(:text)
      @href = attributes[:href]
      @variant = attributes.fetch(:variant, :primary)
      @size = attributes.fetch(:size, :md)
      @full_width = attributes.fetch(:full_width, false)
      @disabled = attributes.fetch(:disabled, false)
      @icon = attributes[:icon]
      @icon_position = attributes.fetch(:icon_position, :left)

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
        'inline-flex items-center justify-center gap-2 font-semibold transition duration-300',
        'focus:outline-none focus:ring-4',
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
        primary: 'bg-[#2563eb] hover:bg-[#1d4ed8] text-white focus:ring-blue-300',
        secondary: 'bg-[#0f172a] hover:bg-[#1d4ed8] text-white focus:ring-blue-300',
        success: 'bg-emerald-500 hover:bg-emerald-600 text-white focus:ring-emerald-300',
        danger: 'bg-red-600 hover:bg-red-700 text-white focus:ring-red-300',
        outline: 'border border-[#2563eb] bg-[#f1f5f9] text-[#0f172a] hover:bg-[#e2e8f0]',
        ghost: 'text-[#0f172a] hover:bg-cyan-50 hover:text-[#2563eb]'
      }.fetch(variant)
    end
  end
end
