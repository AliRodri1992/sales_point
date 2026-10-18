# frozen_string_literal: true

class AddReferenceNotesToAddresses < ActiveRecord::Migration[8.1]
  def change
    add_column :addresses, :reference_notes, :string, limit: 200
  end
end
