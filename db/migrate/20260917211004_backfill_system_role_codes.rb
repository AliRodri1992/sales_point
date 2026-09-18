# frozen_string_literal: true

class BackfillSystemRoleCodes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE system_roles
      SET code = CONCAT(
        REGEXP_REPLACE(LOWER(TRIM(name)), '[^a-z0-9]+', '_', 'g'),
        '_',
        id
      )
      WHERE code IS NULL OR code = ''
    SQL

    change_column_null :system_roles, :code, false
  end

  def down
    change_column_null :system_roles, :code, true
  end
end
