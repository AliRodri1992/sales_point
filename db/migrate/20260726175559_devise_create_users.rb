# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :username
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.string :last_sign_in_ip_country, limit: 2

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      t.string   :unlock_token # Only if unlock strategy is :email or :both
      t.datetime :locked_at

      # ERP
      t.string :user_type, null: false
      t.string :status, default: 'active', null: false
      t.text :locked_Reason
      t.string :unique_session_id
      t.string :current_session_token

      t.datetime :session_expires_at
      t.datetime :session_revoked_at

      t.datetime :login_attempts_window_start

      t.timestamps
      t.timestamp :deleted_at
    end

    ####################################################
    # Constraints
    ####################################################

    add_check_constraint(
      :users,
      "user_type IN ('employee','customer','supplier')",
      name: "chk_users_user_type"
    )

    add_check_constraint(
      :users,
      "status IN ('active','blocked','suspended','deleted')",
      name: "chk_users_status"
    )

    add_index :users,
              "LOWER(email)",
              unique: true,
              name: "idx_users_email"

    add_index :users, :reset_password_token, unique: true
    add_index :users, :deleted_at

    add_index :users, %i[email status]
    # add_index :users, :role_id
    # add_index :users, %i[role_id status]
    add_index :users, :user_type
    add_index :users, :status
    add_index :users, %i[user_type status]
    # add_index :users, :last_failed_attempt_at
    # add_index :users, %i[user_type role_id status]

    add_index :users,
              :status,
              where: "status='active'",
              name: "idx_users_active"

    add_index :users,
              :session_expires_at,
              where: "session_expires_at IS NOT NULL",
              name: "idx_users_session_active"
  end
end
