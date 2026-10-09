# frozen_string_literal: true

module Landing
  class FooterComponent < ViewComponent::Base
    Link = Data.define(:title_key, :href)

    PRODUCT_LINKS = %i[features pricing hardware].freeze
    SUPPORT_LINKS = %i[help_center api_docs server_status].freeze
    COMPANY_LINKS = %i[about sales_contact business_partner].freeze

    def initialize
      super
      @product_links = PRODUCT_LINKS.map { |t| Link.new(t, link_target(t)) }
      @support_links = SUPPORT_LINKS.map { |t| Link.new(t, link_target(t)) }
      @company_links = COMPANY_LINKS.map { |t| Link.new(t, link_target(t)) }
    end

    private

    attr_reader :product_links, :support_links, :company_links

    def link_target(key)
      key == :sales_contact ? '#contacto' : '#'
    end
  end
end
