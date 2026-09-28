# frozen_string_literal: true

module Landing
  class NavbarComponent < ViewComponent::Base
    MenuItem = Data.define(:title, :href)

    def initialize
      super
      @menu_items = [
        MenuItem.new("Solución", "#solucion"),
        MenuItem.new("Características", "#caracteristicas"),
        MenuItem.new("Precios", "#precios"),
        MenuItem.new("Preguntas", "#faq")
      ]
    end

    private

    attr_reader :menu_items
  end
end