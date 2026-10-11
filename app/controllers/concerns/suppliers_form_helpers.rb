# frozen_string_literal: true

module SuppliersFormHelpers
  private

  def load_fiscal_regimes
    @fiscal_regimes = SatFiscalRegime.current.order(:code)
  end

  def load_reference_catalogs
    @currencies = Currency.active.order(:code)
    @countries = Country.active.ordered
  end

  def build_new_supplier
    supplier = current_organization.suppliers.new(supplier_params.except(:status))
    supplier.status = :active
    supplier.contacts.each { |contact| contact.active = true }
    supplier
  end

  def render_supplier_form_error
    load_fiscal_regimes
    load_reference_catalogs
    render :new, status: :unprocessable_content
  end

  def render_supplier_duplicate_error
    @supplier.errors.add(:base, t('admin.suppliers.errors.duplicate'))
    render_supplier_form_error
  end

  def notify_supplier(action)
    Suppliers::NotifyService.call(action:, supplier: @supplier, user: current_user)
  end
end
