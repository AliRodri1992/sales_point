# frozen_string_literal: true

module Landing
  class NavbarComponent < ViewComponent::Base
    MenuItem = Data.define(
      :title,
      :href
    )

    def initialize
      super

      @menu_items = [
        MenuItem.new('Características', '#features'),
        MenuItem.new('Módulos', '#modules'),
        MenuItem.new('Precios', '#pricing'),
        MenuItem.new('FAQ', '#faq')
      ]
    end

    private

    attr_reader :menu_items
  end
end
