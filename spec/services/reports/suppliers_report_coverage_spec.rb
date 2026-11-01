# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier report definitions' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user) }
  let(:scope) { organization.suppliers.where(id: supplier.id) }
  let(:report) { Reports::Definitions::SuppliersReport.new(scope:, organization:, user: actor, locale: :es) }

  before do
    create(:organization_membership, user: actor, organization:)
    allow(actor).to receive(:admin?).and_return(false)
    allow(actor).to receive(:permission?).and_return(false)
  end

  it 'provides a locale-aware report title' do
    expect(report.title).to eq(I18n.t('reports.suppliers.title', locale: :es))
  end

  it 'does not export sensitive columns without separate viewing permissions' do
    expect(report.columns(format: :pdf).size).to eq(4)
    expect(report.columns(format: :xlsx).size).to eq(4)
  end

  it 'includes fiscal and contacts fields only with their own viewing permissions' do
    allow(actor).to receive(:permission?).with('suppliers.fiscal.view').and_return(true)
    expect(report.columns(format: :pdf).size).to eq(5)

    allow(actor).to receive(:permission?).with('suppliers.contacts.view').and_return(true)
    expect(report.columns(format: :pdf).size).to eq(7)
    expect(report.columns(format: :xlsx).size).to eq(7)
  end

  it 'includes commercial credit terms only in spreadsheets when permitted' do
    allow(actor).to receive(:permission?).with('suppliers.commercial.view').and_return(true)
    expect(report.columns(format: :pdf).size).to eq(4)
    expect(report.columns(format: :xlsx).size).to eq(6)
  end

  it 'renders each supplier name and permitted fiscal ID' do
    allow(actor).to receive(:permission?).with('suppliers.fiscal.view').and_return(true)
    columns = report.columns
    values = columns.to_h { |column| [column.fetch(:label), column.fetch(:value).call(supplier)] }
    expect(values.values).to include(supplier.name, supplier.rfc)
  end

  it 'iterates supplier records from the original scoped query' do
    rows = []
    report.each_row { |record| rows << record }
    expect(rows).to eq([supplier])
  end

  it 'creates a predictable filename without leaking data' do
    expect(report.filename).to match(/\Asuppliers_\d{8}_\d{6}\z/)
  end

  it 'rejects unimplemented exporters rather than silently creating files' do
    expect { Reports::ExportService.call(report:, format: :csv) }.to raise_error(KeyError)
  end

  it 'uses the requested report locale for exports' do
    allow(Reports::PdfExporter).to receive(:call) { I18n.locale.to_s }
    expect(Reports::ExportService.call(report:, format: :pdf)).to eq('es')
  end
end
