# frozen_string_literal: true

class CreateUserInvitationsAndEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :users, name: 'chk_users_status'
    add_check_constraint :users, "status IN ('pending','active','suspended','blocked','deleted')", name: 'chk_users_status'

    create_table :user_invitations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :user_invitations, :token_digest, unique: true

    create_table :email_templates do |t|
      t.string :key, null: false
      t.string :locale, null: false, default: 'es'
      t.string :subject, null: false
      t.text :html_body, null: false
      t.text :text_body, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :email_templates, [:key, :locale], unique: true
  end
end
