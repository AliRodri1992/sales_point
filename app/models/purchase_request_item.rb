# frozen_string_literal: true

class PurchaseRequestItem < ApplicationRecord
  belongs_to :purchase_request
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0 }
  validate :product_matches_organization

  private

  def product_matches_organization
    return unless purchase_request && product

    errors.add(:product, :invalid) unless product.organization_id == purchase_request.organization_id
  end
end
