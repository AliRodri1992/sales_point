# frozen_string_literal: true

class AddDeletedAtToSupplierScheduleExceptions < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_schedule_exceptions, :deleted_at, :timestamp
  end
end
