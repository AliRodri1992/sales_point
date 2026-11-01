# frozen_string_literal: true

class CreateSupplierScheduleExceptions < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_schedule_exceptions do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :branch, foreign_key: true
      t.references :supplier_schedule, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.date :starts_on, null: false
      t.date :ends_on
      t.string :reason, null: false
      t.text :notes
      t.timestamps
    end
    add_index :supplier_schedule_exceptions, %i[supplier_id starts_on]
  end
end
