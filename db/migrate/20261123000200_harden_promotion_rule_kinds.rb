# frozen_string_literal: true

class HardenPromotionRuleKinds < ActiveRecord::Migration[8.1]
  def change
    # NOT VALID preserves legacy data. PostgreSQL still enforces both checks
    # for new rows and modifications after the migration.
    add_check_constraint :promotion_conditions,
                         "kind IN ('product', 'category', 'excluded_product', 'excluded_category', " \
                         "'min_quantity', 'min_subtotal', 'customer_segment')",
                         name: 'promotion_condition_kind_allowed', validate: false
    add_check_constraint :promotion_benefits, "kind IN ('percentage', 'fixed_amount')",
                         name: 'promotion_benefit_kind_allowed', validate: false
  end
end
