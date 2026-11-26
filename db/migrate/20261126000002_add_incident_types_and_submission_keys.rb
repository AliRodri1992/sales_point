class AddIncidentTypesAndSubmissionKeys < ActiveRecord::Migration[8.1]
  def up
    create_table :incident_types do |t|
      t.string :code, null: false, index: { unique: true }
      t.boolean :active, null: false, default: true
    end
    execute <<~SQL
      INSERT INTO incident_types (code) VALUES
        ('function'), ('data'), ('display'), ('access'), ('performance'), ('other')
    SQL
    execute "UPDATE incidents SET category = NULL WHERE category = ''"
    add_foreign_key :incidents, :incident_types, column: :category, primary_key: :code
    add_column :incidents, :submission_key, :uuid
    add_index :incidents, %i[organization_id reporter_id submission_key], unique: true
  end

  def down
    remove_column :incidents, :submission_key
    remove_foreign_key :incidents, :incident_types
    drop_table :incident_types
  end
end
