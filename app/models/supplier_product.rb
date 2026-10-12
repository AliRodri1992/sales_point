# frozen_string_literal: true

class SupplierProduct < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  belongs_to :supplier
  belongs_to :product
  belongs_to :currency
  has_many :price_history, class_name: 'SupplierProductPrice', dependent: :restrict_with_exception

  validates :product_id, uniqueness: { scope: %i[organization_id supplier_id presentation_name],
                                       conditions: -> { where(deleted_at: nil) } }
  validates :presentation_name, presence: true, length: { maximum: 80 }
  validates :units_per_package, numericality: { greater_than: 0 }
  validates :purchase_price, :freight_amount, :nonrecoverable_tax,
            numericality: { greater_than_or_equal_to: 0 }
  validates :minimum_quantity, numericality: { greater_than: 0 }
  validates :discount_percent, numericality: { in: 0..100 }
  validates :lead_time_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :consistent_organization
  validate :single_preferred_supplier

  scope :available, -> { where(deleted_at: nil, active: true) }

  after_save :record_price_change, if: :price_snapshot_changed?

  def unit_cost
    amount = purchase_price * (1 - (discount_percent / 100))
    ((amount + freight_amount + nonrecoverable_tax) / units_per_package).round(4)
  end

  private

  def consistent_organization
    errors.add(:supplier, :invalid) if supplier && supplier.organization_id != organization_id
    errors.add(:product, :invalid) if product && product.organization_id != organization_id
  end

  def single_preferred_supplier
    return unless preferred? && organization_id && product_id

    candidates = self.class.available.where(organization_id:, product_id:, preferred: true)
    errors.add(:preferred, :taken) if candidates.where.not(id: id).exists?
  end

  def price_snapshot_changed?
    changed_fields = %w[purchase_price units_per_package discount_percent freight_amount
                        nonrecoverable_tax currency_id presentation_name]
    saved_changes.keys.intersect?(changed_fields)
  end

  def record_price_change
    price_history.create!(
      currency:, purchase_price:, units_per_package:, presentation_name:, discount_percent:,
      freight_amount:, nonrecoverable_tax:, effective_on: Date.current,
      recorded_by_id: PaperTrail.request.whodunnit.presence
    )
  end
end
