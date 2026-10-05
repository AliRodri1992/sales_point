# frozen_string_literal: true

class AddDefaultStatusToCategories < ActiveRecord::Migration[8.1]
  def change
    change_column_default :categories, :status, from: nil, to: 'active'

    # Set existing records with null status to 'active'
    execute "UPDATE categories SET status = 'active' WHERE status IS NULL"
  end
end