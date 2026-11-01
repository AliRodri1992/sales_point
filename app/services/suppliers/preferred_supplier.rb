# frozen_string_literal: true

module Suppliers
  # A product-level preference, never a presentation-level property.
  class PreferredSupplier
    class Conflict < StandardError; end
    class Unavailable < StandardError; end

    def self.call(product:, supplier:, expected_supplier_id:)
      product.with_lock do
        raise Conflict if product.preferred_supplier_id != expected_supplier_id

        validate_supplier!(product, supplier) if supplier
        product.update!(preferred_supplier: supplier)
      end
    end

    def self.validate_supplier!(product, supplier)
      eligible = supplier.organization_id == product.organization_id &&
                 supplier.active? && supplier.deleted_at.nil? &&
                 product.supplier_products.available.exists?(supplier_id: supplier.id)
      raise Unavailable unless eligible
    end

    private_class_method :validate_supplier!
  end
end
