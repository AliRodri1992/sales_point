# frozen_string_literal: true

module SupplierBankAccountCreationGuard
  extend ActiveSupport::Concern

  included do
    before_action :require_available_supplier, only: %i[new create]
  end

  private

  def require_available_supplier
    return if @supplier.active? && @supplier.deleted_at.nil?

    redirect_to admin_supplier_bank_accounts_path(@supplier),
                alert: t('admin.supplier_calendar.supplier_unavailable')
  end
end
