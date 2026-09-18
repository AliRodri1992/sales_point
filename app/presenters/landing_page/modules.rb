module LandingPage
  module Modules
    def self.all
      [
        Feature.new(
          icon: 'building-storefront',
          title: I18n.t('landing.module_items.multibranch.title'),
          description: I18n.t('landing.module_items.multibranch.description'),
          color: :primary
        ),
        Feature.new(
          icon: 'truck',
          title: I18n.t('landing.module_items.purchases.title'),
          description: I18n.t('landing.module_items.purchases.description'),
          color: :primary
        ),
        Feature.new(
          icon: 'banknotes',
          title: I18n.t('landing.module_items.cash_register.title'),
          description: I18n.t('landing.module_items.cash_register.description'),
          color: :primary
        ),
        Feature.new(
          icon: 'user-group',
          title: I18n.t('landing.module_items.users.title'),
          description: I18n.t('landing.module_items.users.description'),
          color: :primary
        ),
        Feature.new(
          icon: 'arrow-path',
          title: I18n.t('landing.module_items.returns.title'),
          description: I18n.t('landing.module_items.returns.description'),
          color: :primary
        ),
        Feature.new(
          icon: 'calculator',
          title: I18n.t('landing.module_items.accounting.title'),
          description: I18n.t('landing.module_items.accounting.description'),
          color: :primary
        )
      ]
    end
  end
end
