module LandingPage
  module Modules
    def self.all
      [
        module_feature(:multibranch, 'building-storefront'),
        module_feature(:purchases, 'truck'),
        module_feature(:cash_register, 'banknotes'),
        module_feature(:users, 'user-group'),
        module_feature(:returns, 'arrow-path'),
        module_feature(:accounting, 'calculator')
      ]
    end

    def self.module_feature(key, icon)
      Feature.new(
        icon: icon,
        title: I18n.t("landing.module_items.#{key}.title"),
        description: I18n.t("landing.module_items.#{key}.description"),
        color: :primary
      )
    end
  end
end
