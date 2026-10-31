# frozen_string_literal: true

# Preference commands stay separate from CRUD for individual supplier presentations.
module SupplierProductPreferences
  def set_preferred
    authorize @supplier, :prefer_products?
    update_preference(@supplier)
  end

  def clear_preferred
    authorize @supplier, :prefer_products?
    raise Suppliers::PreferredSupplier::Conflict unless @offer.preferred?

    update_preference(nil)
  rescue Suppliers::PreferredSupplier::Conflict
    preference_alert('preferred_conflict')
  end

  private

  def update_preference(supplier)
    Suppliers::PreferredSupplier.call(
      product: @offer.product, supplier:,
      expected_supplier_id: params[:expected_supplier_id].presence&.to_i
    )
    key = supplier ? 'preferred_updated' : 'preferred_cleared'
    redirect_to admin_supplier_supplier_products_path(@supplier), notice: t("admin.procurement.#{key}")
  rescue Suppliers::PreferredSupplier::Conflict
    preference_alert('preferred_conflict')
  rescue Suppliers::PreferredSupplier::Unavailable, ActiveRecord::RecordInvalid
    preference_alert('preferred_unavailable')
  end

  def preference_alert(key)
    redirect_to admin_supplier_supplier_products_path(@supplier), alert: t("admin.procurement.#{key}")
  end
end
