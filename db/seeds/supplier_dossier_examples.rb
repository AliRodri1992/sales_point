# frozen_string_literal: true

require 'base64'
require 'stringio'
require_relative 'supplier_demo_documents'

# Repeatable demo records for supplier tabs and progressive lists.
# Never calls external geocoding or overwrites existing user-entered records.
module SupplierDossierExamples
  CONTACTS_PER_FEATURED_SUPPLIER = 14
  ADDRESSES_PER_FEATURED_SUPPLIER = 14
  DOCUMENTS_PER_FEATURED_SUPPLIER = 12
  SCHEDULES_PER_FEATURED_SUPPLIER = 12

  # Transparent 1x1 PNG used only as a recognizable demo attachment.
  DEMO_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lN8AAAAASUVORK5CYII='
  ).freeze

  class << self
    def seed!
      organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
      branches = organization.branches.not_deleted.order(:id).to_a
      mexico = Country.find_by!(iso_alpha2: 'MX')

      codes = (1..SupplierExamples::COUNT).map { |number| format('SUP-%04d', number) }
      suppliers = organization.suppliers.not_deleted.where(code: codes).order(:code)
      suppliers.each do |supplier|
        seed_supplier(supplier, branches, mexico, featured: supplier.code == 'SUP-0001')
      end
    end

    private

    def seed_supplier(supplier, branches, country, featured:)
      seed_contacts(supplier, featured ? CONTACTS_PER_FEATURED_SUPPLIER : 3)
      seed_addresses(supplier, country, featured ? ADDRESSES_PER_FEATURED_SUPPLIER : 3)
      seed_documents(supplier, featured ? DOCUMENTS_PER_FEATURED_SUPPLIER : 2)
      SupplierDemoDocuments.seed!(supplier:, featured:)
      seed_schedules(supplier, branches, featured ? SCHEDULES_PER_FEATURED_SUPPLIER : 2)
      report_supplier(supplier)
    end

    def report_supplier(supplier)
      $stdout.puts "[SEEDS][EXPEDIENTE][OK] #{supplier.code}: contactos=#{supplier.contacts.not_deleted.count} " \
                   "direcciones=#{supplier.addresses.not_deleted.count} " \
                   "documentos=#{supplier.documents.attachments.count} " \
                   "calendarios=#{supplier.supplier_schedules.not_deleted.count}"
    end

    def seed_contacts(supplier, count)
      return if supplier.contacts.with_deleted.count >= count

      (2..count).each do |index|
        email = format('demo.s%<supplier>04d.c%<contact>02d@ejemplo.test',
                       supplier: supplier.id, contact: index)
        contacts = supplier.contacts.with_deleted
        reference = "DEMO-CONTACTO-#{index}"
        # Preserve renamed, archived and manually updated demo contacts.
        next if contacts.exists?(email:) || contacts.exists?(name: "Contacto demo #{index}") ||
                contacts.exists?(notes: reference)

        supplier.contacts.create!(contact_attributes(index, email, reference))
      end
    end

    def contact_attributes(index, email, reference)
      {
        name: "Contacto demo #{index}",
        position: %w[Compras Ventas Logística Facturación][index % 4],
        email: email,
        phone: index.even? ? '5512345678' : nil,
        primary: false,
        active: (index % 4 != 0),
        notes: reference
      }
    end

    def seed_addresses(supplier, country, count)
      return if enough_addresses?(supplier, count)

      count.times do |index|
        reference = "DEMO-DIRECCION-#{index + 1}"
        existing = supplier.addresses.with_deleted
        next if existing.exists?(reference_notes: reference) ||
                existing.exists?(street: "Avenida Ejemplo #{index + 1}", exterior_number: (100 + index).to_s)

        purpose = Address::PURPOSES[index % Address::PURPOSES.length]
        primary = !supplier.addresses.not_deleted.exists?(purpose: purpose, primary: true)
        supplier.addresses.create!(address_attributes(index, country, purpose, primary, reference))
      end
    end

    def address_attributes(index, country, purpose, primary, reference)
      {
        purpose: purpose, primary: primary, country: country,
        street: "Avenida Ejemplo #{index + 1}",
        exterior_number: (100 + index).to_s,
        interior_number: index.even? ? nil : "B#{index}",
        neighborhood: 'Centro', city: 'Cuautitlán Izcalli',
        state: 'Estado de México', postal_code: '54700',
        reference_notes: reference, geocoding_status: :pending,
        latitude: nil, longitude: nil
      }
    end

    def enough_addresses?(supplier, count)
      supplier.addresses.with_deleted.count >= count
    end

    def skip_schedules?(supplier, branches, count)
      branches.empty? || supplier.supplier_schedules.count >= count
    end

    def seed_documents(supplier, count)
      expected_formats = count == DOCUMENTS_PER_FEATURED_SUPPLIER ? SupplierDemoDocuments::FORMATS.length : 1
      return if supplier.documents.attachments.count >= count + expected_formats

      count.times do |index|
        name = format('demo-proveedor-%<code>s-documento-%<number>02d.png',
                      code: supplier.code.downcase, number: index + 1)
        next if supplier.documents.attachments.joins(:blob).exists?(active_storage_blobs: { filename: name })

        supplier.documents.attach(
          io: StringIO.new(DEMO_PNG),
          filename: name,
          content_type: 'image/png'
        )
      end
    end

    def seed_schedules(supplier, branches, count)
      return if skip_schedules?(supplier, branches, count)

      count.times do |index|
        kind = SupplierSchedule::KINDS[index % SupplierSchedule::KINDS.length]
        branch = branches[index % branches.length]
        weekday = index % 7
        notes = "DEMO-CALENDARIO-#{index + 1}"
        attributes = schedule_attributes(branch, kind, weekday, notes)
        slot = attributes.slice(:branch, :kind, :weekday, :starts_at)
        next if supplier.supplier_schedules.exists?(notes:) || supplier.supplier_schedules.exists?(slot)

        supplier.supplier_schedules.create!(attributes)
      end
    end

    def schedule_attributes(branch, kind, weekday, notes)
      { branch: branch, kind: kind, weekday: weekday,
        starts_at: '09:00', ends_at: '11:00', notes: notes }
    end
  end
end
