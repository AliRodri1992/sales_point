# frozen_string_literal: true

class AddLocationConfirmationToAddresses < ActiveRecord::Migration[8.1]
  def change
    add_column :addresses, :location_confirmed_at, :datetime
  end
end
