# frozen_string_literal: true

# Run the same Address model validations used on persistence before the fiscal
# onboarding step advances, without writing either record.
module SupplierFiscalAddressValidation
  ADDRESS_ATTRIBUTES = %i[
    street exterior_number interior_number neighborhood city state country_id postal_code
  ].freeze

  def validate_fiscal_address
    @supplier = current_organization.suppliers.new
    authorize @supplier, :new?
    authorize @supplier, :manage_addresses?

    address = @supplier.addresses.build(fiscal_address_attributes)
    return render json: { valid: true } if address.valid?

    render json: { valid: false, errors: fiscal_address_errors(address) },
           status: :unprocessable_content
  end

  private

  def fiscal_address_attributes
    params.expect(address: ADDRESS_ATTRIBUTES).merge(purpose: 'fiscal', primary: true)
  end

  def fiscal_address_errors(address)
    address.errors.each_with_object({}) do |error, errors|
      field = error.attribute == :country ? :country_id : error.attribute
      errors[field] ||= [error.full_message]
    end
  end
end
