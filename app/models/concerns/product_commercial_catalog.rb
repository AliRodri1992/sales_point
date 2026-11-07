# frozen_string_literal: true

module ProductCommercialCatalog
  extend ActiveSupport::Concern

  included do
    has_many :product_variants, inverse_of: :product, dependent: :restrict_with_error
    has_many :product_presentations, inverse_of: :product, dependent: :restrict_with_error
    has_many :product_barcodes, inverse_of: :product, dependent: :restrict_with_error
    has_many :price_list_items, dependent: :restrict_with_error
    has_many :price_change_events, dependent: :restrict_with_error
    accepts_nested_attributes_for :product_variants, :product_presentations, :product_barcodes,
                                  reject_if: :all_blank, limit: 50
    normalizes :barcode, with: ->(value) { value.strip.presence }
    validate :barcode_available_in_organization
    after_save :synchronize_primary_barcode, if: :saved_change_to_barcode?
    validate :preserve_product_history, if: -> { will_save_change_to_deleted_at? && deleted_at.present? }
    after_save :retire_commercial_options, if: -> { saved_change_to_deleted_at? && deleted_at.present? }
    attr_accessor :price_change_reason
  end

  def gross_margin
    return if price.nil? || !price.positive? || cost.nil?

    ((price - cost) / price * 100).round(2)
  end

  private

  def retire_commercial_options
    [product_variants, product_presentations, product_barcodes].each do |records|
      records.each { |record| record.update!(deleted_at: deleted_at) }
    end
  end

  def preserve_product_history
    dependencies = [supplier_products, inventories, purchase_order_items, purchase_request_items, price_list_items]
    used = dependencies.any? { |records| records.with_deleted.exists? }
    return unless used || price_change_events.pending.exists?

    errors.add(:base, I18n.t('admin.catalog_design.product_has_history'))
  end

  def barcode_available_in_organization
    return if barcode.blank?
    return unless ProductBarcode.where(organization_id:, value: barcode).where.not(product_id: id).exists?

    errors.add(:barcode, :taken)
  end

  def synchronize_primary_barcode
    current = product_barcodes.find_by(primary: true)
    current&.destroy! if current && current.value != barcode
    return if barcode.blank?

    code = product_barcodes.find_or_initialize_by(value: barcode)
    code.update!(organization:, primary: true)
  end
end
