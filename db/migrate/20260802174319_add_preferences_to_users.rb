4# frozen_string_literal: true

class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  DEFAULT_THEME = 'theme-material-red'

  def change
    add_reference :users,
                  :language,
                  foreign_key: true,
                  null: true,
                  index: { where: 'language_id IS NOT NULL' }

    add_column :users,
               :theme,
               :string,
               limit: 50,
               default: DEFAULT_THEME,
               null: false
  end
end
