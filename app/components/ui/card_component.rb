# frozen_string_literal: true

module Ui
  class CardComponent < ViewComponent::Base
    renders_one :header
    renders_one :body
    renders_one :footer

    def initialize(
      padding: true,
      border: true,
      shadow: true,
      hover: false,
      full_height: false
    )
      @padding = padding
      @border = border
      @shadow = shadow
      @hover = hover
      @full_height = full_height
    end

    private

    attr_reader :padding,
                :border,
                :shadow,
                :hover,
                :full_height

    def classes
      class_names(
        'rounded-3xl bg-white transition duration-300',
        @padding ? 'p-6 sm:p-8' : nil,
        @border ? 'border border-slate-200' : nil,
        @shadow ? 'shadow-sm' : nil,
        @hover ? 'hover:-translate-y-1 hover:shadow-xl' : nil,
        @full_height ? 'h-full' : nil
      )
    end
  end
end