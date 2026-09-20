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
        Link.new(I18n.t('landing.navbar.features'), '#features'),
        Link.new(I18n.t('landing.navbar.modules'), '#modules'),
        Link.new(I18n.t('landing.navbar.pricing'), '#pricing'),
        Link.new(I18n.t('landing.navbar.faq'), '#faq')
      ]

      @company_links = [
        Link.new(I18n.t('landing.footer.about'), '#'),
        Link.new(I18n.t('landing.footer.contact'), '#'),
        Link.new(I18n.t('landing.footer.privacy'), '#'),
        Link.new(I18n.t('landing.footer.terms'), '#')
      ]
    end

    private

    attr_reader :product_links, :company_links
  end
end
