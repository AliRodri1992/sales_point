# frozen_string_literal: true

module Landing
  class FooterComponent < ViewComponent::Base
    Link = Data.define(:title, :href)

    def initialize
      super
      @product_links = [
        Link.new("Funcionalidades", "#caracteristicas"),
        Link.new("Planes de Precios", "#precios"),
        Link.new("Hardware Compatible", "#")
      ]
      @company_links = [
        Link.new("Sobre Nosotros", "#"),
        Link.new("Contacto de Ventas", "#contacto"),
        Link.new("Socio Comercial", "#")
      ]
    end

    private

    attr_reader :product_links, :company_links
  end
end
