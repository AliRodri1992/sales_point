# frozen_string_literal: true

class AddSoftDeletionToSupplierSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_schedules, :deleted_at, :datetime
    add_index :supplier_schedules, :deleted_at
  end
end
