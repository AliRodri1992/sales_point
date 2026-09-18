module LandingPage
  module Plans
    def self.all
      [
        Plan.new(
          name: I18n.t('landing.plan_items.starter.name'),
          price: 19,
          description: I18n.t('landing.plan_items.starter.description'),
          featured: false,
          features: [
            I18n.t('landing.plan_items.starter.features.branch_users'),
            I18n.t('landing.plan_items.starter.features.sales_inventory'),
            I18n.t('landing.plan_items.starter.features.basic_reports'),
            I18n.t('landing.plan_items.starter.features.email_support')
          ]
        ),
        Plan.new(
          name: I18n.t('landing.plan_items.professional.name'),
          price: 39,
          description: I18n.t('landing.plan_items.professional.description'),
          featured: true,
          features: [
            I18n.t('landing.plan_items.professional.features.branch_users'),
            I18n.t('landing.plan_items.professional.features.purchases'),
            I18n.t('landing.plan_items.professional.features.cash_returns'),
            I18n.t('landing.plan_items.professional.features.advanced_reports'),
            I18n.t('landing.plan_items.professional.features.priority_support')
          ]
        ),
        Plan.new(
          name: I18n.t('landing.plan_items.enterprise.name'),
          price: 79,
          description: I18n.t('landing.plan_items.enterprise.description'),
          featured: false,
          features: [
            I18n.t('landing.plan_items.enterprise.features.unlimited'),
            I18n.t('landing.plan_items.enterprise.features.roles'),
            I18n.t('landing.plan_items.enterprise.features.accounting'),
            I18n.t('landing.plan_items.enterprise.features.implementation'),
            I18n.t('landing.plan_items.enterprise.features.support')
          ]
        )
      ]
    end
  end
end
