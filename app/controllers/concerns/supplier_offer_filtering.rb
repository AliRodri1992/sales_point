# frozen_string_literal: true

# Organization-scoped product offer browsing for the supplier dossier.
module SupplierOfferFiltering
  private

  def filtered_offers
    scope = @supplier.supplier_products
    scope = params[:archived] == '1' ? scope.with_deleted.where.not(deleted_at: nil) : scope.available
    scope = scope.joins(:product).merge(current_organization.products.not_deleted)
    @search.present? ? filter_offers(scope) : scope
  end

  def filter_offers(scope)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(@search)}%"
    scope.where(
      'products.name ILIKE :term OR products.code ILIKE :term OR products.sku ILIKE :term OR ' \
      'supplier_products.supplier_sku ILIKE :term',
      term:
    )
  end
end
