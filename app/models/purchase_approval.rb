# frozen_string_literal: true

class PurchaseApproval < ApplicationRecord
  belongs_to :organization
  belongs_to :purchase_order
  belongs_to :decided_by, class_name: 'User'

  enum :decision, { approved: 'approved', rejected: 'rejected' }, validate: true
  validates :decision, presence: true
  validate :consistent_organization

  private

  def consistent_organization
    return unless purchase_order

    errors.add(:purchase_order, :invalid) unless purchase_order.organization_id == organization_id
  end
end
