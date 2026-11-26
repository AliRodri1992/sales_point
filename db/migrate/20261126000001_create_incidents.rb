# frozen_string_literal: true

class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incident_daily_counters, id: false do |t|
      t.date :day, primary_key: true
      t.integer :sequence, null: false
    end

    create_table :incidents do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :branch, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.references :duplicate_of, foreign_key: { to_table: :incidents }
      t.string :folio, limit: 21, null: false, index: { unique: true }
      t.string :origin_path
      t.string :origin_screen
      t.string :affected_module
      t.string :affected_screen
      t.string :reporter_role
      t.string :category
      t.text :description, null: false
      t.text :expected_result
      t.boolean :blocks_operation
      t.string :frequency
      t.datetime :occurred_at
      t.string :operation_reference
      t.string :request_reference
      t.string :app_version
      t.string :status, default: 'reported', null: false
      t.string :priority
      t.text :resolution
      t.datetime :resolved_at
      t.string :github_state, default: 'pending', null: false
      t.bigint :github_issue_number
      t.string :github_issue_url
      t.timestamps
      t.index %i[organization_id reporter_id created_at]
    end

    create_table :incident_events do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.text :body
      t.timestamps
    end
  end
end
