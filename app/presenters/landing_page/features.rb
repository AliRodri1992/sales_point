module LandingPage
  module Features
    def self.all
      [
        Feature.new(
          icon: 'bolt',
          title: I18n.t('landing.features.items.fast_sales.title'),
          description: I18n.t('landing.features.items.fast_sales.description'),
          color: :emerald
        ),
        Feature.new(
          icon: 'inventory',
          title: I18n.t('landing.features.items.inventory_control.title'),
          description: I18n.t('landing.features.items.inventory_control.description'),
          color: :teal
        ),
        Feature.new(
          icon: 'chart',
          title: I18n.t('landing.features.items.analytics_reports.title'),
          description: I18n.t('landing.features.items.analytics_reports.description'),
          color: :dark_emerald
        )
      ]
    end
  end
end
