module LandingPage
  module Features
    def self.all
      [
        feature(:quick_sales, 'shopping-cart', :blue),
        feature(:realtime_inventory, 'cube', :emerald),
        feature(:customers, 'users', :purple),
        feature(:reports, 'chart-bar', :amber),
        feature(:billing, 'document-text', :red),
        feature(:any_device, 'device-phone-mobile', :cyan)
      ]
    end

    def self.feature(key, icon, color)
      Feature.new(
        icon: icon,
        title: I18n.t("landing.feature_items.#{key}.title"),
        description: I18n.t("landing.feature_items.#{key}.description"),
        color: color
      )
    end
  end
end
