# frozen_string_literal: true

module SupplierPrimaryDossierExamples
  private

  def build_primary_dossier(supplier, number)
    country = Country.find_by!(iso_alpha2: 'MX')
    supplier.contacts.build(
      name: "Contacto #{number}", email: "contacto#{number}@example.com",
      position: 'Ventas', primary: true, active: true,
      notes: 'Contacto ficticio para demostración.'
    )
    supplier.addresses.build(
      purpose: 'fiscal', primary: true, country:,
      street: "Avenida Ejemplo #{number}", exterior_number: (100 + number).to_s,
      neighborhood: 'Centro', city: 'Cuautitlán Izcalli',
      state: 'Estado de México', postal_code: '54700'
    )
  end
end
