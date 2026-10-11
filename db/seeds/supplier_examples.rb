# frozen_string_literal: true

# Sample tenant and suppliers for a fresh development database.
# Codes and RFCs are deterministic so db:seed can be run repeatedly.
module SupplierExamples
  COUNT = 20
  ORGANIZATION_TAX_ID = 'DPO260101AB1'
  ORGANIZATION_NAME = 'Delta POS'

  def self.seed!
    organization = create_organization
    create_membership(organization)
    create_suppliers_for(organization)
    Rails.logger.info "Seeded #{COUNT} suppliers for organization #{organization.id}"
  end

  class << self
    private

    def create_organization
      organization = Organization.find_or_initialize_by(tax_id: ORGANIZATION_TAX_ID)
      organization.assign_attributes(
        name: ORGANIZATION_NAME,
        business_sector: 'grocery',
        base_currency: Currency.find_by!(code: 'MXN'),
        status: :active
      )
      organization.save!
      organization
    end

    def create_membership(organization)
      admin = User.find_by!(email: 'administrador@delta.com')
      membership = OrganizationMembership.find_or_initialize_by(organization:, user: admin)
      membership.assign_attributes(status: :active, deleted_at: nil)
      membership.save!
    end

    def create_suppliers_for(organization)
      COUNT.times do |index|
        number = index + 1
        create_supplier(organization, number)
      end
    end

    def create_supplier(organization, number)
      code = format('SUP-%04d', number)
      supplier = Supplier.find_or_initialize_by(organization:, code:)
      supplier.assign_attributes(
        name: "Proveedor de ejemplo #{number}",
        person_type: :company,
        email: "proveedor#{number}@example.com",
        phone: format('55%08d', number),
        rfc: format('DPE260101%03d', number),
        postal_code: format('%05d', 60_000 + number),
        status: (number % 5).zero? ? :inactive : :active,
        notes: "Proveedor de demostración #{number} para Delta POS.",
        deleted_at: nil
      )
      supplier.save!
      create_contact(supplier, number)
    end

    def create_contact(supplier, number)
      email = "contacto#{number}@example.com"
      contact = supplier.contacts.find_by(email:)

      if contact
        update_existing_contact(contact, supplier, number)
      else
        create_new_contact(supplier, number, email)
      end
    end

    def update_existing_contact(contact, supplier, number)
      contact.update!(
        name: "Contacto #{number}",
        position: 'Ventas',
        phone: supplier.phone,
        active: true,
        deleted_at: nil
      )
    end

    def create_new_contact(supplier, number, email)
      supplier.contacts.create!(
        name: "Contacto #{number}",
        email: email,
        position: 'Ventas',
        phone: supplier.phone,
        primary: true,
        active: true,
        deleted_at: nil
      )
    end
  end
end
