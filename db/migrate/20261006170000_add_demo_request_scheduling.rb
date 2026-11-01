class AddDemoRequestScheduling < ActiveRecord::Migration[8.1]
  def change
    add_column :demo_requests, :scheduled_at, :datetime
    add_column :demo_requests, :reminder_24h_sent_at, :datetime
    add_column :demo_requests, :reminder_1h_sent_at, :datetime
    add_column :demo_requests, :locale, :string, null: false, default: 'es'
  end
end
