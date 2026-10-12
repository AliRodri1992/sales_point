# frozen_string_literal: true

class PurchaseRequest < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  belongs_to :branch
  belongs_to :requested_by, class_name: 'User'
  has_many :purchase_request_items, dependent: :restrict_with_exception
  has_many :purchase_quotations, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception

  accepts_nested_attributes_for :purchase_request_items, reject_if: :all_blank
  enum :status, { draft: 'draft', submitted: 'submitted', approved: 'approved',
                  rejected: 'rejected', cancelled: 'cancelled' }, validate: true

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validate :branch_belongs_to_organization
  validate :products_belong_to_organization

  before_validation :set_code, on: :create

  private

  def set_code
    self.code ||= "REQ-#{SecureRandom.hex(5).upcase}"
  end

  def branch_belongs_to_organization
    errors.add(:branch, :invalid) if branch && branch.organization_id != organization_id
  end

  def products_belong_to_organization
    purchase_request_items.each do |item|
      errors.add(:purchase_request_items, :invalid) if item.product && item.product.organization_id != organization_id
    end
  end
end
