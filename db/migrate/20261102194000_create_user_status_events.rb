# frozen_string_literal: true

class CreateUserStatusEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :user_status_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.text :reason, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :user_status_events, [:user_id, :created_at]
  end
end
