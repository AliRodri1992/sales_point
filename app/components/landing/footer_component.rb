# frozen_string_literal: true

module Landing
  class FooterComponent < ViewComponent::Base
    Link = Data.define(
      :title,
      :href
    )

    def initialize
      super

      @product_links = [
        Link.new('Características', '#features'),
        Link.new('Módulos', '#modules'),
        Link.new('Precios', '#pricing'),
        Link.new('FAQ', '#faq')
      ]

      @company_links = [
        Link.new('Nosotros', '#'),
        Link.new('Contacto', '#'),
        Link.new('Privacidad', '#'),
        Link.new('Términos', '#')
      ]
    end

    private

    attr_reader :product_links, :company_links
  end
end