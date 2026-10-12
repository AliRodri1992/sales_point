# frozen_string_literal: true

class UniqueActiveSupplierScheduleSlots < ActiveRecord::Migration[8.1]
  def change
    remove_index :supplier_schedules, name: 'idx_supplier_schedules_unique_slot'
    add_index :supplier_schedules, %i[supplier_id branch_id kind weekday starts_at],
              unique: true, where: 'deleted_at IS NULL',
              name: 'idx_supplier_schedules_unique_slot'
  end
end
