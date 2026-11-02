# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier report definitions' do
  include SqlQueryRecorder

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

  it 'never exports contact details to users who can only create contacts' do
    allow(actor).to receive(:permission?).with('suppliers.contacts.create').and_return(true)
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

  it 'preserves supplier order while preloading contacts in bounded batches' do
    stub_const('Reports::Definitions::SuppliersReport::EXPORT_BATCH_SIZE', 2)
    names = %w[Alpha Bravo Charlie]
    names.each do |name|
      create(:supplier, organization:, name:)
    end
    ordered_scope = organization.suppliers.where(name: names).order(name: :desc)
    batch_report = Reports::Definitions::SuppliersReport.new(
      scope: ordered_scope, organization:, user: actor, locale: :es
    )

    rows = []
    statements = []
    statements = recorded_sql_queries do
      batch_report.each_row do |record|
        expect(record.association(:contacts)).to be_loaded
        rows << record.name
      end
    end

    expect(rows).to eq(names.reverse)
    expect(statements.grep(/FROM\\s+"?contacts"?/i).size).to eq(2)
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
  it 'never exports private columns for an anonymous user or an inactive membership' do
    anonymous_report = Reports::Definitions::SuppliersReport.new(scope:, organization:, user: nil, locale: :es)
    expect(anonymous_report.columns(format: :xlsx).size).to eq(4)

    organization.organization_memberships.find_by!(user: actor).update!(status: :inactive)
    allow(actor).to receive(:permission?).and_return(true)
    expect(report.columns(format: :xlsx).size).to eq(4)
  end

  it 'allows authorized report fields through manage permissions and administrator access' do
    allow(actor).to receive(:permission?).with('suppliers.contacts.manage').and_return(true)
    allow(actor).to receive(:permission?).with('suppliers.fiscal.manage').and_return(true)
    expect(report.columns(format: :pdf).size).to eq(7)

    allow(actor).to receive(:admin?).and_return(true)
    expect(report.columns(format: :xlsx).size).to eq(9)
  end

  it 'renders blank classifications and missing primary office numbers without leaking other phones' do
    allow(actor).to receive(:permission?).with('suppliers.contacts.view').and_return(true)
    supplier.update!(classification: nil)
    values = report.columns.to_h { |column| [column.fetch(:label), column.fetch(:value).call(supplier)] }
    expect(values[I18n.t('reports.suppliers.columns.classification', locale: :es)]).to eq('')
    expect(values[I18n.t('reports.suppliers.columns.phone', locale: :es)]).to eq('')

    contact = create(:contact, contactable: supplier, primary: true, active: true)
    supplier.reload
    expect(report.columns.find { |column| column[:label] == I18n.t('reports.suppliers.columns.phone', locale: :es) }
                 .fetch(:value).call(supplier)).to eq('')

    phone = contact.phones.create!(
      organization:, kind: 'landline', country_code: 'MX', number: '5512345678', primary: true
    )
    supplier.reload
    expect(report.columns.find { |column| column[:label] == I18n.t('reports.suppliers.columns.phone', locale: :es) }
                 .fetch(:value).call(supplier)).to eq(phone.reload.number)
  end
end
