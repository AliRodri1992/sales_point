# frozen_string_literal: true

module SuppliersFormHelpers
  private

  def load_fiscal_regimes
    @fiscal_regimes = SatFiscalRegime.current.order(:code)
  end

  def notify_supplier(action)
    Suppliers::NotifyService.call(action:, supplier: @supplier, user: current_user)
  end
end
