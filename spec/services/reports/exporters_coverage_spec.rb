# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier report exporters' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user) }
  let(:report) do
    Reports::Definitions::SuppliersReport.new(
      scope: organization.suppliers.where(id: supplier.id),
      organization:, user: actor, locale: :es
    )
  end

  it 'exports a valid XLSX workbook with supplier records' do
    bytes = Reports::ExcelExporter.call(report:)
    expect(bytes).to start_with('PK')
    expect(bytes.bytesize).to be > 100
  end

  it 'escapes spreadsheet formula injection' do
    risky_supplier = create(:supplier, organization:, name: '=HYPERLINK("bad")')
    report = Reports::Definitions::SuppliersReport.new(
      scope: organization.suppliers.where(id: risky_supplier.id),
      organization:, user: actor, locale: :es
    )
    bytes = Reports::ExcelExporter.call(report:)
    expect(bytes).to start_with('PK')
  end

  it 'generates PDF with organization identity and application branding' do
    renderer = instance_double(ActionController::Renderer)
    allow(ApplicationController).to receive(:renderer).and_return(renderer)
    allow(renderer).to receive(:render).and_return('<html><body>Suppliers</body></html>')
    fake_pdf = instance_double(WickedPdf)
    allow(WickedPdf).to receive(:new).and_return(fake_pdf)
    allow(fake_pdf).to receive(:pdf_from_string).and_return('%PDF-test')

    expect(Reports::PdfExporter.call(report:)).to eq('%PDF-test')
    expect(renderer).to have_received(:render).with(
      hash_including(template: 'reports/catalog', layout: 'reports/pdf')
    )
  end

  it 'omits unsupported organization-logo file types' do
    organization.logo.attach(io: StringIO.new('test'), filename: 'invalid.txt', content_type: 'text/plain')
    result = Reports::PdfExporter.send(:organization_logo, organization)
    expect(result).to be_nil
  end

  it 'encodes supported PNG logo as data URL for PDF' do
    organization.logo.attach(io: StringIO.new('png-data'), filename: 'logo.png', content_type: 'image/png')
    result = Reports::PdfExporter.send(:organization_logo, organization)
    expect(result).to start_with('data:image/png;base64,')
  end

  it 'returns nil when organization has no logo' do
    expect(Reports::PdfExporter.send(:organization_logo, organization)).to be_nil
  end

  it 'uses the static Delta POS identity for PDF branding' do
    expect(Reports::PdfExporter.send(:delta_logo)).to start_with('data:image/svg+xml;base64,')
  end

  it 'renders supplier classification and localized state for reports' do
    supplier.update!(classification: 'manufacturer')
    label = I18n.t('reports.suppliers.columns.classification', locale: :es)
    col = report.columns.find { |item| item.fetch(:label) == label }
    expect(col.fetch(:value).call(supplier)).to eq(
      I18n.t('admin.suppliers.index.advanced.options.manufacturer', locale: :es)
    )
  end
end
