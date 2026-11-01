module LandingPage
  module Features
    ITEMS = [
      %i[fast_sales bolt emerald],
      %i[inventory_control inventory teal],
      %i[analytics_reports chart dark_emerald]
    ].freeze

    def self.all
      ITEMS.map do |key, icon, color|
        Feature.new(
          icon: icon,
          title: I18n.t("landing.features.items.#{key}.title"),
          description: I18n.t("landing.features.items.#{key}.description"),
          color: color
        )
      end
    end
  end
end
