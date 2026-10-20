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

  def add_file(name, type: 'application/pdf', content: '%PDF-1.4 example')
    supplier.documents.attach(io: StringIO.new(content), filename: name, content_type: type)
  end

  def select_document(name)
    find("button[data-action='supplier-documents#select'][aria-label='View details for #{name}']").click
  end

  def close_drawer
    find('[data-supplier-documents-target="closeButton"]').click
  end

  scenario 'opens a right-side drawer for the selected file instead of an inline preview' do
    add_file('Supplier contract.pdf')
    add_file('Tax certificate.pdf')

    visit admin_supplier_path(supplier, tab: 'documents')

    expect(page).to have_css('[data-supplier-documents-target="dialog"].hidden', visible: :all)
    expect(page).to have_css('[data-supplier-documents-target="card"] button[aria-pressed="false"]', count: 2)
    expect(page).to have_css('[data-supplier-documents-target="list"]')

    select_document('Supplier contract.pdf')
    expect(page).to have_css('[data-supplier-documents-target="dialog"]:not(.hidden)')
    expect(page).to have_css('[role="dialog"][aria-modal="true"]')
    expect(page).to have_css('[data-supplier-documents-target="previewName"]', text: 'Supplier contract.pdf')
    expect(page).to have_css('[data-supplier-documents-target="previewFrame"][src*="/preview"]', visible: :all)
    expect(page).to have_css('[data-supplier-documents-target="card"] button[aria-pressed="true"]', count: 1)

    close_drawer
    expect(page).to have_css('[data-supplier-documents-target="dialog"].hidden', visible: :all)

    select_document('Tax certificate.pdf')
    expect(page).to have_css('[data-supplier-documents-target="previewName"]', text: 'Tax certificate.pdf')
    expect(page).to have_css('[data-supplier-documents-target="card"] button[aria-pressed="true"]', count: 1)
    expect(page).to have_css('button[data-section="contacts"]', visible: :all)
    expect(page).to have_css('button[data-section="addresses"]', visible: :all)
  end

  scenario 'previews a text document without injecting its contents into HTML' do
    add_file('Notes.txt', type: 'text/plain', content: 'Supplier notes <script>alert(1)</script>')
    add_file('Terms.pdf')

    visit admin_supplier_path(supplier, tab: 'documents')

    select_document('Notes.txt')
    preview = find('[data-supplier-documents-target="previewText"]')
    expect(preview).to have_text('Supplier notes <script>alert(1)</script>')
    expect(page).to have_no_css('[data-supplier-documents-target="previewText"] script')

    close_drawer
    select_document('Terms.pdf')
    expect(page).to have_css('[data-supplier-documents-target="previewText"].hidden', visible: :all)
    expect(page).to have_css('[data-supplier-documents-target="previewFrame"][src*="/preview"]', visible: :all)
  end

  scenario 'leaves the list at full width when filters hide the selected file' do
    add_file('Supplier contract.pdf')
    add_file('Tax certificate.pdf')

    visit admin_supplier_path(supplier, tab: 'documents')

    select_document('Supplier contract.pdf')
    close_drawer

    find('[data-supplier-documents-target="search"]').set('certificate')
    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 1)
    expect(page).to have_css('[data-supplier-documents-target="dialog"].hidden', visible: :all)

    select_document('Tax certificate.pdf')
    expect(page).to have_css('[data-supplier-documents-target="previewName"]', text: 'Tax certificate.pdf')

    close_drawer
    find('[data-supplier-documents-target="search"]').set('')
    find('button[data-category="contract"]', text: 'Contracts').click
    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 1)
    expect(page).to have_css('[data-supplier-documents-target="range"]', text: 'Showing 1–1 of 1')
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
