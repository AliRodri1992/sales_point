# frozen_string_literal: true

class Inventory < ApplicationRecord
  belongs_to :organization
  belongs_to :branch
  belongs_to :product
  has_many :inventory_movements, dependent: :restrict_with_exception

  validates :product_id, uniqueness: { scope: :branch_id }
  validates :stock, :min_stock, numericality: { greater_than_or_equal_to: 0 }
  validates :max_stock, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :consistent_organization
  validate :valid_stock_limits

  scope :low_stock, -> { where('min_stock > 0 AND stock <= min_stock') }

  def low_stock? = min_stock.positive? && stock <= min_stock

  private

  def consistent_organization
    errors.add(:branch, :invalid) if branch && branch.organization_id != organization_id
    errors.add(:product, :invalid) if product && product.organization_id != organization_id
  end

  def valid_stock_limits
    return if max_stock.nil? || min_stock.nil?

    errors.add(:max_stock, :greater_than_min) if max_stock < min_stock
  end
end
