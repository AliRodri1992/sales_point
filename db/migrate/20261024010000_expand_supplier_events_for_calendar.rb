# frozen_string_literal: true

class ExpandSupplierEventsForCalendar < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_events, :all_day, :boolean, null: false, default: false
    add_column :supplier_events, :status, :string, null: false, default: 'scheduled'
    add_index :supplier_events, %i[supplier_id status starts_at], name: 'idx_supplier_events_status_date'
    add_check_constraint :supplier_events,
                         "status IN ('scheduled', 'completed', 'cancelled')",
                         name: 'chk_supplier_event_status'
    add_check_constraint :supplier_events, 'ends_at IS NULL OR ends_at > starts_at',
                         name: 'chk_supplier_event_period'
  end
end
