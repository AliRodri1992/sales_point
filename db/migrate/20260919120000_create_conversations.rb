class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :conversation_type, default: "direct", null: false
      t.datetime :deleted_at, precision: nil
      t.timestamps
    end

    add_index :conversations, :deleted_at
    add_index :conversations, [:conversation_type, :deleted_at]

    create_table :conversation_participants do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :deleted_at, precision: nil
      t.timestamps
    end

    add_index :conversation_participants, :deleted_at
    add_index :conversation_participants,
              [:conversation_id, :user_id],
              unique: true,
              where: "deleted_at IS NULL",
              name: "idx_conv_participants_unique_active"

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.datetime :deleted_at, precision: nil
      t.timestamps
    end

    add_index :messages, :deleted_at
    add_index :messages, [:conversation_id, :created_at]
  end
end
