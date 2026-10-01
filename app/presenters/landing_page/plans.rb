module LandingPage
  module Plans
    def self.all
      [
        Plan.new(
          name: I18n.t("landing.plan_items.starter.name"),
          price: 29,
          description: I18n.t("landing.plan_items.starter.description"),
          features: [
            I18n.t("landing.plan_items.starter.features.branch_users"),
            I18n.t("landing.plan_items.starter.features.sales_inventory")
          ],
          featured: false
        ),
        Plan.new(
          name: I18n.t("landing.plan_items.professional.name"),
          price: 59,
          description: I18n.t("landing.plan_items.professional.description"),
          features: [
            I18n.t("landing.plan_items.professional.features.branch_users"),
            I18n.t("landing.plan_items.professional.features.purchases"),
            I18n.t("landing.plan_items.professional.features.cash_returns"),
            I18n.t("landing.plan_items.professional.features.advanced_reports"),
            I18n.t("landing.plan_items.professional.features.priority_support")
          ],
          featured: true
        )
      ]
    end
  end
end