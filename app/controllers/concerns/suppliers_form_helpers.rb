# frozen_string_literal: true

module SuppliersFormHelpers
  private

  def supplier_scalar_attributes
    %i[
      code name legal_name trade_name alias_name classification person_type
      email phone rfc foreign_tax_id sat_fiscal_regime_id status notes
      currency_id credit_days credit_limit discount_percent minimum_order_amount
      responsible_user_id tags_text
    ]
  end

  def authorize_supplier_attributes!(attributes)
    policy_record = @supplier
    authorize policy_record, :manage_contacts? if attributes.key?(:contacts_attributes)
    authorize policy_record, :manage_addresses? if attributes.key?(:addresses_attributes)
    authorize policy_record, :manage_documents? if attributes.key?(:documents)

    fiscal_fields = %w[rfc foreign_tax_id sat_fiscal_regime_id person_type]
    commercial_fields = %w[currency_id credit_days credit_limit discount_percent minimum_order_amount]
    authorize policy_record, :manage_fiscal? if attributes.keys.map(&:to_s).intersect?(fiscal_fields)
    authorize policy_record, :manage_commercial? if attributes.keys.map(&:to_s).intersect?(commercial_fields)
  end

  def validate_primary_dossier_submission!(attributes, creating:)
    return if primary_dossier_submission_valid?(attributes, creating:)

    @supplier.errors.add(:base, :invalid)
    render_supplier_form_error
  end

  def primary_dossier_submission_valid?(attributes, creating:)
    valid_primary_records?(attributes[:contacts_attributes], :contacts, creating:) &&
      valid_primary_records?(attributes[:addresses_attributes], :addresses, creating:)
  end

  def valid_primary_records?(raw, association, creating:)
    return true if raw.blank?

    records = raw.respond_to?(:values) ? raw.values : Array(raw)
    return false if records.size > 1

    records.all? { |record| valid_primary_record?(record, association, creating:) }
  end

  def valid_primary_record?(record, association, creating:)
    return false unless valid_primary_flags?(record, association)
    return record[:id].blank? if creating

    return existing_primary_record?(record, association) if record[:id].present?

    no_primary_record?(association)
  end

  def valid_primary_flags?(record, association)
    return false if ActiveModel::Type::Boolean.new.cast(record[:_destroy])
    return false if record.key?(:primary) && !ActiveModel::Type::Boolean.new.cast(record[:primary])

    association != :addresses || !record.key?(:purpose) || record[:purpose] == 'fiscal'
  end

  def existing_primary_record?(record, association)
    existing = @supplier.public_send(association).not_deleted.find_by(id: record[:id])
    existing&.primary? && (association != :addresses || existing.purpose == 'fiscal')
  end

  def no_primary_record?(association)
    @supplier.public_send(association).not_deleted.where(
      primary: true, **(association == :addresses ? { purpose: 'fiscal' } : {})
    ).none?
  end

  def normalize_primary_dossier_attributes!(attributes)
    %i[contacts addresses].each do |association|
      nested = attributes[:"#{association}_attributes"]
      next if nested.blank?

      records = nested.respond_to?(:values) ? nested.values : Array(nested)
      records.each do |record|
        record[:primary] = true
        record[:purpose] = 'fiscal' if association == :addresses
      end
    end
    attributes
  end

  def enqueue_nested_address_geocoding
    @supplier.addresses.target.each do |address|
      next unless address.persisted? && address.deleted_at.nil? && !address.location_confirmed?
      next unless address.saved_change_to_id? ||
                  address.saved_changes.keys.intersect?(Address::GEOGRAPHIC_FIELDS)

      GeocodeAddressJob.perform_later(address.id, address.geocoding_fingerprint)
    end
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
    supplier.contacts.each do |contact|
      contact.active = true
      contact.primary = true
    end
    supplier.addresses.each do |address|
      address.purpose = 'fiscal'
      address.primary = true
    end
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

  def supplier_update_destination
    return admin_supplier_path(@supplier, tab: 'general') if params[:return_to] == 'general'

    admin_suppliers_path
  end

  def supplier_update_attributes
    attributes = supplier_params
    uploads = attributes.delete(:documents)
    attributes[:documents] = @supplier.documents.blobs.to_a + uploads if uploads.present?
    attributes
  end

  def notify_supplier(action)
    Suppliers::NotifyService.call(action:, supplier: @supplier, user: current_user)
  end
end
