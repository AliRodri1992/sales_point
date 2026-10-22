# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier-filtered accounts payable', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:other_supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, :system, code: 'administrator'))
    sign_in user
  end

  def payable_for(supplier_record, folio)
    invoice = SupplierInvoice.create!(
      organization:, supplier: supplier_record, currency: supplier_record.currency, created_by: user,
      issued_on: Date.current, received_on: Date.current, due_on: Date.current + 15.days,
      subtotal: 200, total: 200, tax_amount: 0, discount: 0, status: :posted, folio:
    )
    AccountPayable.create!(organization:, supplier: supplier_record, supplier_invoice: invoice,
                           amount: 200, due_on: invoice.due_on)
  end

  it 'filters payables and sums by supplier and allows going back to the statement' do
    payable_for(supplier, 'SUP-001')
    payable_for(other_supplier, 'OTHER-001')

    get admin_account_payables_path(supplier_id: supplier.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('SUP-001', supplier.name)
    expect(response.body).not_to include('OTHER-001', other_supplier.name)
    expect(response.body).to include(admin_supplier_path(supplier, tab: 'statement'))
    expect(Nokogiri::HTML(response.body).at_css('tbody').css('tr').size).to eq(1)
  end

  it 'retains all suppliers in the independent global finance list' do
    payable_for(supplier, 'SUP-001')
    payable_for(other_supplier, 'OTHER-001')

    get admin_account_payables_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('SUP-001', 'OTHER-001')
    expect(Nokogiri::HTML(response.body).at_css('tbody').css('tr').size).to eq(2)
  end

  it 'paginates payables without affecting organization-wide totals' do
    22.times { |index| payable_for(supplier, "PAGE-#{index}") }

    get admin_account_payables_path(page: 1)
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(20)
    expect(response.body).to include('22')

    get admin_account_payables_path(page: 2)
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(2)
  end

  it 'rejects a supplier from a different organization' do
    outsider = create(:supplier, organization: create(:organization))

    get admin_account_payables_path(supplier_id: outsider.id)

    expect(response).to have_http_status(:not_found)
  end
end
