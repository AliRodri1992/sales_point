class AddUniqueIndexToCodeOnLanguages < ActiveRecord::Migration[8.1]
  def change
    add_index :languages, :code, unique: true, where: 'deleted_at IS NULL'
  end
end
