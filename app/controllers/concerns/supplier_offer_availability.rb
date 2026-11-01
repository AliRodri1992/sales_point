# frozen_string_literal: true

# Prevent publishing a new purchasing offer for an unavailable supplier.
module SupplierOfferAvailability
  private

  def require_active_supplier
    return if @supplier.active?

    redirect_to admin_supplier_supplier_products_path(@supplier),
                alert: t('admin.supplier_archive.unavailable_supplier')
  end
end
