# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/seeds/supplier_examples')
require Rails.root.join('db/seeds/supplier_dossier_examples')

RSpec.describe SupplierDossierExamples do
  let!(:admin) { create(:user, email: 'administrador@delta.com') }
  let!(:currency) { create(:currency, code: 'MXN') }

  before do
    create(:country, name: 'México', iso_alpha2: 'MX', iso_alpha3: 'MEX', iso_numeric: '484')
    SupplierExamples.seed!
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    create(:branch, :without_address, organization:)
  end

  it 'keeps contacts, addresses, attachments and schedules idempotent after manual edits' do
    described_class.seed!
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    supplier = organization.suppliers.find_by!(code: 'SUP-0001')
    contact = supplier.contacts.find_by!(name: 'Contacto demo 2')
    address = supplier.addresses.find_by!(reference_notes: 'DEMO-DIRECCION-1')
    schedule = supplier.supplier_schedules.find_by!(notes: 'DEMO-CALENDARIO-1')

    counts = [
      Contact.where(contactable_type: 'Supplier', contactable_id: organization.suppliers.select(:id)).count,
      Address.where(addressable_type: 'Supplier', addressable_id: organization.suppliers.select(:id)).count,
      SupplierSchedule.where(supplier_id: organization.suppliers.select(:id)).count,
      ActiveStorage::Attachment.where(record_type: 'Supplier',
                                      record_id: organization.suppliers.select(:id)).count
    ]
    contact.update!(email: 'renamed.demo@example.com')
    address.update!(reference_notes: 'Dirección revisada manualmente')
    schedule.update!(notes: 'Calendario revisado manualmente')

    described_class.seed!

    later_counts = [
      Contact.where(contactable_type: 'Supplier', contactable_id: organization.suppliers.select(:id)).count,
      Address.where(addressable_type: 'Supplier', addressable_id: organization.suppliers.select(:id)).count,
      SupplierSchedule.where(supplier_id: organization.suppliers.select(:id)).count,
      ActiveStorage::Attachment.where(record_type: 'Supplier',
                                      record_id: organization.suppliers.select(:id)).count
    ]
    expect(later_counts).to eq(counts)
    expect(contact.reload.email).to eq('renamed.demo@example.com')
    expect(address.reload.reference_notes).to eq('Dirección revisada manualmente')
    expect(schedule.reload.notes).to eq('Calendario revisado manualmente')
  end
end
