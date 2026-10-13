# frozen_string_literal: true

class PurchaseQuotation < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  belongs_to :supplier
  belongs_to :purchase_request, optional: true
  belongs_to :currency
  has_many :purchase_quotation_items, dependent: :restrict_with_exception

  accepts_nested_attributes_for :purchase_quotation_items, reject_if: :all_blank
  enum :status, { draft: 'draft', submitted: 'submitted', accepted: 'accepted',
                  rejected: 'rejected', expired: 'expired' }, validate: true

  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validate :consistent_organization
  before_validation :set_code, on: :create

  def valid_offer?
    submitted? && (valid_until.nil? || valid_until >= Date.current)
  end

  private

  def set_code
    self.code ||= "QT-#{SecureRandom.hex(5).upcase}"
  end

  def consistent_organization
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
    return unless purchase_request

    valid = purchase_request.organization_id == organization_id && purchase_request.approved?
    errors.add(:purchase_request, :invalid) unless valid
  end
end
