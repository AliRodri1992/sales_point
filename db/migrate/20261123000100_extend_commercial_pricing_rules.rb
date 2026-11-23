# frozen_string_literal: true

class ExtendCommercialPricingRules < ActiveRecord::Migration[8.1]
  PRICE_KEY = 'price_list_id WITH =, product_id WITH =, COALESCE(product_variant_id, 0) WITH =, ' \
              'COALESCE(product_presentation_id, 0) WITH ='
  PERIOD = "tsrange(starts_at, ends_at, '[)') WITH &&"
  PREVIOUS_PRECISION = {
    price_list_items: { price: [12, 2] },
    price_change_events: { previous_price: [12, 2], new_price: [12, 2] },
    promotion_benefits: { value: [12, 4] },
    promotion_conditions: { amount: [12, 2] },
    promotion_redemptions: { discount: [12, 2] }
  }.freeze

  def change
    add_column :price_lists, :priority, :integer, null: false, default: 0
    add_column :price_lists, :default_list, :boolean, null: false, default: false
    add_column :promotions, :priority, :integer, null: false, default: 0
    add_column :promotions, :maximum_discount, :decimal, precision: 18, scale: 8
    add_column :promotions, :combination_mode, :string, null: false, default: 'best_price'
    add_reference :promotions, :price_list, type: :bigint
    add_foreign_key :promotions, :price_lists, column: [:organization_id, :price_list_id],
                    primary_key: [:organization_id, :id]
    add_check_constraint :promotions, 'maximum_discount IS NULL OR maximum_discount > 0',
                         name: 'promotion_positive_cap'
    add_check_constraint :promotions, "combination_mode IN ('best_price', 'exclusive')",
                         name: 'promotion_combination_modes'
    add_column :price_list_items, :minimum_quantity, :decimal, precision: 18, scale: 6, null: false, default: 0
    add_check_constraint :price_list_items, 'minimum_quantity >= 0', name: 'price_item_minimum_quantity'
    reversible do |direction|
      direction.up do
        replace_price_periods("#{PRICE_KEY}, minimum_quantity WITH =, #{PERIOD}")
        PREVIOUS_PRECISION.each do |table, columns|
          columns.each_key { |column| change_column table, column, :decimal, precision: 18, scale: 8 }
        end
      end
      direction.down do
        PREVIOUS_PRECISION.each do |table, columns|
          columns.each do |col, (precision, scale)|
            if select_value("SELECT 1 FROM #{table} WHERE #{col} <> round(#{col}, #{scale}) LIMIT 1")
              raise ActiveRecord::IrreversibleMigration, "Rollback would round historical #{table}.#{col}"
            end
            change_column table, col, :decimal, precision:, scale:
          end
        end
        replace_price_periods("#{PRICE_KEY}, #{PERIOD}")
      end
    end
  end

  private

  def replace_price_periods(definition)
    remove_exclusion_constraint :price_list_items, name: 'commercial_price_periods'
    add_exclusion_constraint :price_list_items, definition, where: 'deleted_at IS NULL', using: :gist,
                             deferrable: :deferred, name: 'commercial_price_periods'
  end
end
