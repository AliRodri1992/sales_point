# frozen_string_literal: true

module SupplierLifecycle
  extend ActiveSupport::Concern

  OPEN_PURCHASE_STATUSES = %w[draft pending_approval approved ordered partially_received].freeze

  included do
    after_update :clear_unavailable_product_preferences, if: :supplier_became_unavailable?
  end

  def archivable?
    if purchase_orders.exists?(status: OPEN_PURCHASE_STATUSES)
      errors.add(:base, I18n.t('admin.suppliers.lifecycle.open_orders'))
    end
    errors.add(:base, I18n.t('admin.suppliers.lifecycle.draft_invoices')) if supplier_invoices.exists?(status: 'draft')
    if account_payables.with_positive_balance.exists?
      errors.add(:base, I18n.t('admin.suppliers.lifecycle.outstanding_payables'))
    end
    errors.empty?
  end

  private

  def supplier_became_unavailable?
    (saved_change_to_status? || saved_change_to_deleted_at?) && (inactive? || deleted_at.present?)
  end

  def clear_unavailable_product_preferences
    Product.where(preferred_supplier_id: id).order(:id).find_each do |product|
      product.with_lock do
        product.update!(preferred_supplier: nil) if product.preferred_supplier_id == id
      end
    end
  end
end
