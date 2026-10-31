# frozen_string_literal: true

module SupplierParameters
  private

  def supplier_params
    params.expect(supplier: [*supplier_scalar_attributes, supplier_nested_params])
  end

  def supplier_nested_params
    {
      contacts_attributes: [[
        :id, :name, :position, :email, :primary, :active, :notes, :_destroy,
        { phones_attributes: [phone_field_params] }
      ]],
      addresses_attributes: [[
        :id, :street, :exterior_number, :interior_number, :neighborhood, :city,
        :state, :country_id, :postal_code, :purpose, :primary, :_destroy
      ]],
      documents: []
    }
  end

  def phone_field_params
    %i[id number country_code kind label extension primary whatsapp_enabled _destroy]
  end
end
