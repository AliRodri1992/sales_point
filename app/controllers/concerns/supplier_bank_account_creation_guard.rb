# frozen_string_literal: true

module SupplierBankAccountCreationGuard
  private

  def require_available_supplier
    return if @supplier.active? && @supplier.deleted_at.nil?

    redirect_to admin_supplier_bank_accounts_path(@supplier),
                alert: t('admin.supplier_calendar.supplier_unavailable')
  end
end
