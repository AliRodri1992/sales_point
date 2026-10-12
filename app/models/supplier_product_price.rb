# frozen_string_literal: true

class SupplierProductPrice < ApplicationRecord
  belongs_to :supplier_product
  belongs_to :currency
  belongs_to :recorded_by, class_name: 'User', optional: true

  validates :effective_on, presence: true
  validates :purchase_price, :freight_amount, :nonrecoverable_tax,
            numericality: { greater_than_or_equal_to: 0 }
  validates :units_per_package, numericality: { greater_than: 0 }
  validates :discount_percent, numericality: { in: 0..100 }

  before_update :prevent_changes
  before_destroy :prevent_changes

  private

  def prevent_changes
    errors.add(:base, :readonly)
    throw :abort
  end
end
