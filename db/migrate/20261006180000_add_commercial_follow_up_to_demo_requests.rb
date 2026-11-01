class AddCommercialFollowUpToDemoRequests < ActiveRecord::Migration[8.1]
  def change
    change_table :demo_requests, bulk: true do |t|
      t.datetime :contacted_at
      t.string :contact_channel, limit: 30
      t.string :contact_outcome, limit: 40
      t.datetime :next_follow_up_at
      t.string :next_action, limit: 120
      t.string :demo_outcome, limit: 40
      t.datetime :converted_at
    end

    add_index :demo_requests, :next_follow_up_at
    add_index :demo_requests, :contact_outcome
    add_index :demo_requests, :demo_outcome
  end
end
