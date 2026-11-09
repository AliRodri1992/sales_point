# frozen_string_literal: true

# Product-only invariants. Inventory is consulted through its public records;
# lifecycle rules for inventory movements remain owned by the inventory module.
module ProductCatalogIntegrity
  extend ActiveSupport::Concern

  included do
    validate :valid_primary_barcode_format
    validate :sku_available_among_variants, if: -> { sku.present? }
    validate :preserve_tracking_history, if: -> { persisted? && will_save_change_to_tracking_mode? }
  end

  private

  def valid_primary_barcode_format
    return if barcode.blank? || Products::BarcodeFormat.valid?(barcode, 'code128')

    errors.add(:barcode, :invalid)
  end

  def sku_available_among_variants
    persisted = ProductVariant.where(organization_id:).exists?(['lower(sku) = lower(?)', sku])
    nested = product_variants.any? do |variant|
      !variant.marked_for_destruction? && variant.sku.present? && variant.sku.casecmp?(sku)
    end
    errors.add(:sku, :taken) if persisted || nested
  end

  def preserve_tracking_history
    inventory_scope = Inventory.with_deleted.where(organization_id:, product_id: id)
    used = inventory_scope.where.not(stock: 0).exists?
    used ||= InventoryMovement.with_deleted.exists?(inventory_id: inventory_scope.select(:id))
    used ||= InventoryLot.with_deleted.exists?(inventory_id: inventory_scope.select(:id))
    errors.add(:tracking_mode, I18n.t('admin.catalog_design.tracking_mode_locked')) if used
  end
end
