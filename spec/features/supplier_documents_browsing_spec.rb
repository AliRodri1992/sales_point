# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier documents browsing', type: :feature, js: true do
  include Warden::Test::Helpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :english) }
  let(:supplier) { create(:supplier, organization:) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    Warden.test_mode!
    login_as(user, scope: :user)
  end

  after { Warden.test_reset! }

  def add_file(name)
    supplier.documents.attach(
      io: StringIO.new('%PDF-1.4 example'),
      filename: name,
      content_type: 'application/pdf'
    )
  end

  scenario 'filters documents while keeping the preview and other supplier sections' do
    add_file('Supplier contract.pdf')
    add_file('Tax certificate.pdf')

    visit admin_supplier_path(supplier, tab: 'documents')

    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 2)
    find('[data-supplier-documents-target="search"]').set('contract')

    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 1)
    expect(page).to have_css('[data-supplier-documents-target="previewName"]', text: 'Supplier contract.pdf')
    expect(page).to have_css('button[data-section="contacts"]')
    expect(page).to have_css('button[data-section="addresses"]')

    find('[data-supplier-documents-target="search"]').set('')
    find('button[data-category="fiscal"]', text: 'Tax').click
    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 1)
    expect(page).to have_css('[data-supplier-documents-target="previewName"]', text: 'Tax certificate.pdf')
  end

  scenario 'paginates eight cards without hiding the supplier navigation' do
    10.times { |number| add_file("Supplier file #{number}.pdf") }

    visit admin_supplier_path(supplier, tab: 'documents')

    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 8)
    find('[data-action="supplier-documents#next"]').click
    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 2)
    expect(page).to have_css('[data-supplier-documents-target="page"]', text: '2')
  end
end
