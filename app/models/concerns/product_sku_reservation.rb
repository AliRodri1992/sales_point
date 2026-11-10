# frozen_string_literal: true

# Each successful ActiveRecord save reserves its SKU in a shared, uniquely
# indexed table. Both Product and ProductVariant participate in this contract.
module ProductSkuReservation
  extend ActiveSupport::Concern

  included do
    after_save :synchronize_product_sku_claim, if: :saved_sku_claim_state?
    after_destroy :release_product_sku_claim
  end

  private

  def saved_sku_claim_state?
    saved_change_to_sku? || saved_change_to_deleted_at?
  end

  def synchronize_product_sku_claim
    claim = ProductSkuClaim.find_by(organization_id:, owner_type: self.class.name, owner_id: id)
    if sku.blank? || deleted_at.present?
      claim&.destroy!
      return
    end

    claim ||= ProductSkuClaim.new(organization:, owner_type: self.class.name, owner_id: id)
    claim.normalized_sku = sku.downcase
    claim.save!
  end

  def release_product_sku_claim
    ProductSkuClaim.where(organization_id:, owner_type: self.class.name, owner_id: id).find_each(&:destroy!)
  end
end
