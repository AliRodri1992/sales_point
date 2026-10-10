# frozen_string_literal: true

# Sample tenant and suppliers for a fresh development database.
# Codes and RFCs are deterministic so db:seed can be run repeatedly.
module SupplierExamples
  COUNT = 20
  ORGANIZATION_TAX_ID = 'DPO260101AB1'
  ORGANIZATION_NAME = 'Delta POS Demo'

  def self.seed!
    organization = Organization.find_or_initialize_by(tax_id: ORGANIZATION_TAX_ID)
    organization.assign_attributes(
      name: ORGANIZATION_NAME,
      business_sector: 'grocery',
      status: :active
    )
    organization.save!

    admin = User.find_by!(email: 'administrador@delta.com')
    membership = OrganizationMembership.find_or_initialize_by(organization:, user: admin)
    membership.assign_attributes(status: :active, deleted_at: nil)
    membership.save!

    COUNT.times do |index|
      number = index + 1
      code = format('SUP-%04d', number)
      supplier = Supplier.find_or_initialize_by(organization:, code:)
      supplier.assign_attributes(
        name: "Proveedor de ejemplo #{number}",
        email: "proveedor#{number}@example.com",
        phone: format('55%08d', number),
        rfc: format('DPE260101%03d', number),
        postal_code: format('%05d', 60_000 + number),
        status: number % 5 == 0 ? :inactive : :active,
        notes: "Proveedor de demostración #{number} para Delta POS.",
        deleted_at: nil
      )
      supplier.save!

      contact = supplier.contacts.find_or_initialize_by(email: "contacto#{number}@example.com")
      contact.assign_attributes(
        name: "Contacto #{number}",
        position: 'Ventas',
        phone: supplier.phone,
        primary: true,
        active: true,
        deleted_at: nil
      )
      contact.save!
    end

    Rails.logger.info "Seeded #{COUNT} suppliers for organization #{organization.id}"
  end
end
