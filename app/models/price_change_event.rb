# frozen_string_literal: true

class PriceChangeEvent < ApplicationRecord
  include CommercialTenant

  belongs_to :product
  belongs_to :price_list_item, optional: true
  belongs_to :actor, -> { with_deleted }, class_name: 'User', inverse_of: false
  belongs_to :approved_by, -> { with_deleted }, class_name: 'User', inverse_of: false, optional: true
  enum :status, { pending: 'pending', approved: 'approved', rejected: 'rejected' }, validate: true, default: :pending
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :reason, presence: true, length: { maximum: 1000 }
  validates :new_price, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
  validates :previous_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :same_organization
  validate :immutable_history, on: :update
  before_destroy { throw :abort }

  private

  def same_organization
    validate_commercial_parent(product, :product)
    if price_list_item
      validate_commercial_parent(price_list_item, :price_list_item)
      errors.add(:price_list_item, :invalid) if price_list_item.product_id != product_id
    end
    return unless approved? && (approved_by_id.nil? || approved_at.nil?)

    errors.add(:approved_by, :blank)
  end

  def immutable_history
    mutable = %w[status approved_by_id approved_at updated_at]
    invalid_change = changes_to_save.keys.any? { |attribute| mutable.exclude?(attribute) }
    errors.add(:base, :invalid) if invalid_change || status_in_database != 'pending'
  end
end
