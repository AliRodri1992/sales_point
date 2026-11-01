# frozen_string_literal: true

module SupplierFormCatalogs
  private

  def load_fiscal_regimes
    @fiscal_regimes = SatFiscalRegime.current.order(:code)
  end

  def load_reference_catalogs
    @currencies = Currency.active.order(:code)
    @countries = Country.active.ordered
  end
end
