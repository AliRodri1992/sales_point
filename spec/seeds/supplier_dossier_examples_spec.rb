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

  it 'backfills authentic document formats without duplicating or overwriting attachments' do
    described_class.seed!
    org = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    featured = org.suppliers.find_by!(code: 'SUP-0001')
    sample_prefix = "delta-demo-#{featured.code.downcase}-"
    samples = featured.documents.attachments.joins(:blob)
                      .where('active_storage_blobs.filename LIKE ?', "#{sample_prefix}%")
    names = samples.map { |attachment| attachment.blob.filename.to_s }

    expect(names.count).to eq(SupplierDemoDocuments::FORMATS.length)
    expect(names).to include(
      "#{sample_prefix}constancia.pdf", "#{sample_prefix}nota.txt",
      "#{sample_prefix}contrato.docx", "#{sample_prefix}precios.xlsx",
      "#{sample_prefix}identificacion.jpg", "#{sample_prefix}fotografia.png",
      "#{sample_prefix}catalogo.csv", "#{sample_prefix}informacion.xml"
    )
    pdf = samples.find { |item| item.blob.filename.extension == 'pdf' }.blob.download
    expect(pdf).to start_with('%PDF-1.4')
    expect(pdf).to include('xref', '%%EOF')
    %w[docx xlsx].each do |extension|
      blob = samples.find { |item| item.blob.filename.extension == extension }.blob
      Zip::File.open_buffer(blob.download) do |archive|
        expect(archive.find_entry('[Content_Types].xml')).to be_present
      end
    end
    jpg = samples.find { |item| item.blob.filename.extension == 'jpg' }.blob.download
    expect(jpg.bytes.first(3)).to eq([255, 216, 255])
    png = samples.find { |item| item.blob.filename.extension == 'png' }.blob.download
    expect(png.bytes.first(8)).to eq([137, 80, 78, 71, 13, 10, 26, 10])

    original_ids = featured.documents.attachments.order(:id).pluck(:id)
    manual = featured.documents.attach(
      io: StringIO.new('Documento agregado por usuario'),
      filename: 'contrato-manual.txt', content_type: 'text/plain'
    )
    count_with_manual = featured.documents.attachments.count

    described_class.seed!

    expect(featured.documents.attachments.count).to eq(count_with_manual)
    expect(featured.documents.attachments.where(id: original_ids).count).to eq(original_ids.length)
    expect(manual).to be_present
  end

  it 'seeds dated visits and deliveries only once, retaining edits and archived records' do
    described_class.seed!
    supplier = Supplier.find_by!(code: 'SUP-0001')
    events = supplier.supplier_events.with_deleted.order(:id)
    expect(events.count).to eq(5)
    expect(events.pluck(:all_day)).to include(true, false)
    expect(events.pluck(:status)).to include('scheduled', 'completed')

    event = events.first
    event.update!(title: 'Personalized visit', notes: 'Edited manually')
    event.update!(deleted_at: Time.current)
    described_class.seed!

    expect(supplier.supplier_events.with_deleted.count).to eq(5)
    expect(event.reload.title).to eq('Personalized visit')
    expect(event.deleted_at).to be_present
  end

  it 'does not attach dossier examples to suppliers created manually in the demo tenant' do
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)
    manual = create(:supplier, organization:, code: 'MANUAL-SUP')
    document = manual.documents.attach(
      io: StringIO.new('Archivo del usuario'), filename: 'original.txt', content_type: 'text/plain'
    )
    original_ids = manual.documents.attachments.pluck(:id)

    2.times { described_class.seed! }

    expect(manual.reload.contacts).to be_empty
    expect(manual.addresses).to be_empty
    expect(manual.supplier_schedules).to be_empty
    expect(manual.documents.attachments.pluck(:id)).to eq(original_ids)
    expect(document).to be_present
  end

  it 'distributes additional document formats across the other suppliers' do
    described_class.seed!
    organization = Organization.find_by!(tax_id: SupplierExamples::ORGANIZATION_TAX_ID)

    suppliers = organization.suppliers.where.not(code: 'SUP-0001')
    expect(suppliers.count).to eq(SupplierExamples::COUNT - 1)
    suppliers.each do |supplier|
      names = supplier.documents.attachments.map { |attachment| attachment.blob.filename.to_s }
      expect(names.grep(/\Adelta-demo-/).length).to eq(1)
    end
    extensions = suppliers.flat_map(&:documents).map { |attachment| attachment.blob.filename.extension }.uniq
    expect(extensions).to include('pdf', 'txt', 'docx', 'xlsx', 'jpg')
  end

  it 'does not recreate records after user changes all their demo identifiers' do
    described_class.seed!
    supplier = Supplier.find_by!(code: 'SUP-0001')
    contact = supplier.contacts.find_by!(name: 'Contacto demo 2')
    address = supplier.addresses.find_by!(reference_notes: 'DEMO-DIRECCION-1')
    schedule = supplier.supplier_schedules.find_by!(notes: 'DEMO-CALENDARIO-1')
    counts = [supplier.contacts.with_deleted.count, supplier.addresses.with_deleted.count,
              supplier.supplier_schedules.count, supplier.documents.attachments.count]

    contact.update!(name: 'Responsable personalizado', email: 'personalizado@ejemplo.test', notes: nil)
    address.update!(street: 'Avenida Personalizada', exterior_number: '999', reference_notes: nil)
    schedule.update!(notes: 'Horario personalizado', starts_at: '12:00', ends_at: '14:00')

    described_class.seed!

    expect([supplier.contacts.with_deleted.count, supplier.addresses.with_deleted.count,
            supplier.supplier_schedules.count, supplier.documents.attachments.count]).to eq(counts)
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
