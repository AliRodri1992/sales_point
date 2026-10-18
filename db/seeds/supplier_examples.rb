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
      if organization.new_record?
        organization.assign_attributes(name: ORGANIZATION_NAME, business_sector: 'grocery', status: :active)
        organization.save!
      end
      $stdout.puts "[SEEDS][ORGANIZACION][OK] id=#{organization.id} nombre=#{organization.name}"
      settings = OrganizationSetting.find_or_initialize_by(organization: organization)
      if settings.new_record?
        settings.assign_attributes(base_currency: Currency.active.find_by!(code: 'MXN'),
                                   timezone: 'America/Mexico_City', payment_method: :cash)
        settings.save!
      end
      $stdout.puts "[SEEDS][CONFIGURACION][OK] organizacion_id=#{organization.id} " \
                   "moneda=#{settings.base_currency.code}"
      organization
    end

    def create_membership(organization)
      admin = User.find_by!(email: 'administrador@delta.com')
      membership = OrganizationMembership.find_or_initialize_by(organization:, user: admin)
      if membership.new_record?
        membership.assign_attributes(status: :active, deleted_at: nil)
        membership.save!
      end
      $stdout.puts "[SEEDS][MEMBRESIA][OK] usuario_id=#{admin.id} " \
                   "organizacion_id=#{organization.id} estado=#{membership.status}"
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
      attributes = supplier_attributes(number, organization)
      if supplier.new_record?
        supplier.assign_attributes(attributes)
        supplier.save!
      else
        fill_missing_details(supplier, attributes)
      end
      create_contact(supplier, number)
    end

    def supplier_attributes(number, organization)
      {
        name: "Proveedor de ejemplo #{number}",
        legal_name: "Comercializadora Demo #{number}, S.A. de C.V.",
        trade_name: "Distribuidora Demo #{number}",
        alias_name: "Demo #{number}",
        classification: %w[manufacturer distributor wholesaler][number % 3],
        person_type: :company,
        email: "proveedor#{number}@example.com",
        phone: format('55%08d', number),
        rfc: format('DPE260101%03d', number),
        postal_code: format('%05d', 60_000 + number),
        status: (number % 5).zero? ? :inactive : :active,
        currency: Currency.active.find_by!(code: 'MXN'),
        credit_days: number.even? ? 30 : 15,
        credit_limit: number * 10_000,
        discount_percent: (number % 4),
        minimum_order_amount: 500 + (number * 100),
        tags: %w[demostracion compras],
        responsible_user: organization.users.find_by(email: 'administrador@delta.com'),
        notes: "Proveedor de demostración #{number} para Delta POS.",
        deleted_at: nil
      }
    end

    def fill_missing_details(supplier, attributes)
      fields = %i[legal_name trade_name alias_name classification responsible_user]
      fields.each do |field|
        supplier.public_send("#{field}=", attributes[field]) if supplier.public_send(field).blank?
      end
      supplier.tags = attributes[:tags] if supplier.tags.blank?
      supplier.save! if supplier.changed?
    end

    def create_contact(supplier, number)
      # A manually renamed or archived primary contact must not be recreated.
      return if supplier.contacts.exists?

      create_new_contact(supplier, number, "contacto#{number}@example.com")
    end

    def create_new_contact(supplier, number, email)
      supplier.contacts.create!(
        name: "Contacto #{number}",
        email: email,
        position: 'Ventas',
        phone: supplier.phone,
        mobile_phone: supplier.phone,
        notes: 'Contacto ficticio para demostración.',
        primary: true,
        active: true,
        deleted_at: nil
      )
    end
  end
end
