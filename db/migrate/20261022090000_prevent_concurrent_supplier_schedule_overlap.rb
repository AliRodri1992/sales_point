# frozen_string_literal: true

class PreventConcurrentSupplierScheduleOverlap < ActiveRecord::Migration[8.1]
  def up
    enable_extension 'btree_gist'
    execute <<~SQL
      ALTER TABLE supplier_schedules ADD CONSTRAINT supplier_schedules_no_overlap
      EXCLUDE USING gist (
        supplier_id WITH =, branch_id WITH =, kind WITH =, weekday WITH =,
        int4range(
          extract(epoch FROM starts_at)::integer,
          COALESCE(extract(epoch FROM ends_at)::integer,
                   extract(epoch FROM starts_at)::integer + 60),
          '[)'
        ) WITH &&
      ) WHERE (deleted_at IS NULL);
    SQL
  end

  def down
    execute 'ALTER TABLE supplier_schedules DROP CONSTRAINT IF EXISTS supplier_schedules_no_overlap'
  end
end
