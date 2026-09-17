# frozen_string_literal: true

module Ui
  class IconBoxComponent < ViewComponent::Base
    SIZES = %i[
      sm
      md
      lg
      xl
    ].freeze

    COLORS = %i[
      primary
      success
      warning
      danger
      dark
      blue
      emerald
      purple
      amber
      red
      cyan
    ].freeze

    def initialize(
      icon:,
      size: :md,
      color: :primary,
      rounded: :xl
    )
      @icon = icon
      @size = size
      @color = color
      @rounded = rounded
    end

    private

    attr_reader :icon,
                :size,
                :color,
                :rounded

    def icon_name
      icon.to_s.tr('_', '-')
    end

    def wrapper_classes
      class_names(
        'inline-flex items-center justify-center shadow-lg',
        size_classes,
        rounded_classes,
        color_classes
      )
    end

    def icon_classes
      {
        sm: 'h-5 w-5',
        md: 'h-7 w-7',
        lg: 'h-8 w-8',
        xl: 'h-10 w-10'
      }.fetch(size)
    end

    def size_classes
      {
        sm: 'h-10 w-10',
        md: 'h-14 w-14',
        lg: 'h-16 w-16',
        xl: 'h-20 w-20'
      }.fetch(size)
    end

    def rounded_classes
      {
        lg: 'rounded-lg',
        xl: 'rounded-xl',
        xxl: 'rounded-2xl',
        full: 'rounded-full'
      }.fetch(rounded)
    end

    def color_classes
      {
        primary: 'bg-blue-100 text-blue-600',
        blue: 'bg-blue-100 text-blue-600 transition group-hover:bg-blue-600 group-hover:text-white',
        emerald: 'bg-emerald-100 text-emerald-600 transition group-hover:bg-emerald-600 group-hover:text-white',
        purple: 'bg-purple-100 text-purple-600 transition group-hover:bg-purple-600 group-hover:text-white',
        amber: 'bg-amber-100 text-amber-600 transition group-hover:bg-amber-500 group-hover:text-white',
        red: 'bg-red-100 text-red-600 transition group-hover:bg-red-600 group-hover:text-white',
        cyan: 'bg-cyan-100 text-cyan-600 transition group-hover:bg-cyan-600 group-hover:text-white',
        success: 'bg-emerald-100 text-emerald-600',
        warning: 'bg-amber-100 text-amber-600',
        danger: 'bg-red-100 text-red-600',
        dark: 'bg-slate-900 text-white'
      }.fetch(color)
    end
  end
end