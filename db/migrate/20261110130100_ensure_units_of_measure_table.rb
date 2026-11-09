# frozen_string_literal: true

# Existing installations and db:schema:load may mark earlier timestamps as
# applied even when this new catalog table is absent from their old schema.
# Keep the original migration beside Products and repair only that gap.
class EnsureUnitsOfMeasureTable < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:units_of_measure)

    require_relative '20261003184001_create_units_of_measure'
    CreateUnitsOfMeasure.new.migrate(:up)
  end

  def down
    # Retaining this table avoids destructive rollback of previously stored units.
  end
end
