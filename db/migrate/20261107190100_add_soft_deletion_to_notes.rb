# frozen_string_literal: true

class AddSoftDeletionToNotes < ActiveRecord::Migration[8.1]
  def up
    add_column :notes, :deleted_at, :datetime
    add_index :notes, :deleted_at

    remove_index :notes, name: 'idx_notes_notable_kind'
    add_index :notes, %i[notable_type notable_id kind], unique: true,
                      where: 'deleted_at IS NULL', name: 'idx_notes_notable_kind'
  end

  def down
    remove_index :notes, name: 'idx_notes_notable_kind'
    add_index :notes, %i[notable_type notable_id kind], unique: true, name: 'idx_notes_notable_kind'

    remove_index :notes, :deleted_at
    remove_column :notes, :deleted_at
  end
end
