module LandingPage
  module Plans
    def self.all
      [
        plan(:starter, 19, false, %i[branch_users sales_inventory basic_reports email_support]),
        plan(:professional, 39, true, %i[branch_users purchases cash_returns advanced_reports priority_support]),
        plan(:enterprise, 79, false, %i[unlimited roles accounting implementation support])
      ]
    end

    def self.plan(key, price, featured, feature_keys)
      Plan.new(
        name: I18n.t("landing.plan_items.#{key}.name"),
        price: price,
        description: I18n.t("landing.plan_items.#{key}.description"),
        featured: featured,
        features: feature_keys.map do |feature|
          I18n.t("landing.plan_items.#{key}.features.#{feature}")
        end
      )
    end
  end
end
