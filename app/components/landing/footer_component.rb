# frozen_string_literal: true

module Landing
  class FooterComponent < ViewComponent::Base
    Link = Data.define(:title_key, :href)

    def initialize
      super
      @product_links = [
        Link.new("features", "#caracteristicas"),
        Link.new("pricing", "#precios"),
        Link.new("hardware", "#")
      ]
      @support_links = [
        Link.new("help_center", "#"),
        Link.new("api_docs", "#"),
        Link.new("server_status", "#")
      ]
      @company_links = [
        Link.new("about", "#"),
        Link.new("sales_contact", "#contacto"),
        Link.new("business_partner", "#")
      ]
    end

    private

    attr_reader :product_links, :support_links, :company_links
  end
end
