# frozen_string_literal: true

# Validates preferred suppliers against the same product and tenant.
module PreferredSupplierValidation
  extend ActiveSupport::Concern

  included do
    belongs_to :preferred_supplier, class_name: 'Supplier', optional: true
    validate :preferred_supplier_is_eligible, if: :will_save_change_to_preferred_supplier_id?
  end

  private

  def preferred_supplier_is_eligible
    return if preferred_supplier_id.nil?

    candidate = preferred_supplier
    valid_supplier = candidate && candidate.organization_id == organization_id &&
                     candidate.active? && candidate.deleted_at.nil?
    return if valid_supplier && supplier_products.available.exists?(supplier_id: candidate.id)

    errors.add(:preferred_supplier, :invalid)
  end
end
