# frozen_string_literal: true

# NOT VALID avoids failing a deployment because of legacy rows, but PostgreSQL
# enforces these constraints on every new or updated row immediately.
class HardenCategoryDataConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :categories, "name IS NOT NULL AND btrim(name) <> ''",
                         name: 'chk_categories_name_present', validate: false
    add_check_constraint :categories, "code IS NOT NULL AND code ~ '^[a-z0-9_]{1,20}$'",
                         name: 'chk_categories_code_valid', validate: false
    add_check_constraint :categories, "status IS NOT NULL AND status IN ('active', 'inactive')",
                         name: 'chk_categories_status_valid', validate: false
  end
end
