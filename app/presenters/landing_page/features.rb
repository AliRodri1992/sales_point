module LandingPage
  module Features
    def self.all
      [
        Feature.new(
          icon: 'shopping-cart',
          title: I18n.t('landing.feature_items.quick_sales.title'),
          description: I18n.t('landing.feature_items.quick_sales.description'),
          color: :blue
        ),
        Feature.new(
          icon: 'cube',
          title: I18n.t('landing.feature_items.realtime_inventory.title'),
          description: I18n.t('landing.feature_items.realtime_inventory.description'),
          color: :emerald
        ),
        Feature.new(
          icon: 'users',
          title: I18n.t('landing.feature_items.customers.title'),
          description: I18n.t('landing.feature_items.customers.description'),
          color: :purple
        ),
        Feature.new(
          icon: 'chart-bar',
          title: I18n.t('landing.feature_items.reports.title'),
          description: I18n.t('landing.feature_items.reports.description'),
          color: :amber
        ),
        Feature.new(
          icon: 'document-text',
          title: I18n.t('landing.feature_items.billing.title'),
          description: I18n.t('landing.feature_items.billing.description'),
          color: :red
        ),
        Feature.new(
          icon: 'device-phone-mobile',
          title: I18n.t('landing.feature_items.any_device.title'),
          description: I18n.t('landing.feature_items.any_device.description'),
          color: :cyan
        )
      ]
    end
  end
end
