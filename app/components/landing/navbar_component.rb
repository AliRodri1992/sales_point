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
        MenuItem.new(I18n.t('landing.navbar.features'), '#features'),
        MenuItem.new(I18n.t('landing.navbar.modules'), '#modules'),
        MenuItem.new(I18n.t('landing.navbar.pricing'), '#pricing'),
        MenuItem.new(I18n.t('landing.navbar.faq'), '#faq')
      ]
    end

    private

    attr_reader :menu_items
  end
end
