# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier document server pagination', type: :request do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:user) { create(:user, :english) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    sign_in user
    11.times do |number|
      supplier.documents.attach(
        io: StringIO.new("%PDF-1.4 example #{number}"), filename: "Supplier #{number}.pdf",
        content_type: 'application/pdf'
      )
    end
  end

  it 'limits the initial render to eight files and retrieves the next three from PostgreSQL' do
    get admin_supplier_path(supplier, tab: 'documents')
    document = Nokogiri::HTML(response.body)
    expect(document.css('[data-supplier-documents-target="card"]').size).to eq(8)
    expect(document.at_css('[data-supplier-documents-server-total-value]')['data-supplier-documents-server-total-value']).to eq('11')

    get admin_supplier_path(supplier, tab: 'documents', documents_page: 2)
    expect(Nokogiri::HTML(response.body).css('[data-supplier-documents-target="card"]').size).to eq(3)
  end

  it 'applies a filename filter before pagination' do
    get admin_supplier_path(supplier, tab: 'documents', documents_q: 'Supplier 10')

    cards = Nokogiri::HTML(response.body).css('[data-supplier-documents-target="card"]')
    expect(cards.size).to eq(1)
    expect(cards.first['data-filename']).to eq('Supplier 10.pdf')
  end
end
