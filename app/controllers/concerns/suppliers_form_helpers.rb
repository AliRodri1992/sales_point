# frozen_string_literal: true

module SuppliersFormHelpers
  private

  def authorize_supplier_attributes!(attributes)
    policy_record = @supplier
    authorize policy_record, :manage_contacts? if attributes.key?(:contacts_attributes)
    authorize policy_record, :manage_addresses? if attributes.key?(:addresses_attributes)
    authorize policy_record, :manage_documents? if attributes.key?(:documents)

    fiscal_fields = %w[rfc sat_fiscal_regime_id postal_code person_type]
    commercial_fields = %w[currency_id credit_days credit_limit discount_percent minimum_order_amount]
    authorize policy_record, :manage_fiscal? if (attributes.keys.map(&:to_s) & fiscal_fields).any?
    authorize policy_record, :manage_commercial? if (attributes.keys.map(&:to_s) & commercial_fields).any?
  end

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
