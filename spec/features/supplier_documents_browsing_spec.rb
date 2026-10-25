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
    expect(page).to have_css('[data-supplier-documents-target="list"] article', count: 2)
    expect(page).to have_no_css('table[data-supplier-documents-target="list"]')
    expect(page).to have_css('[data-supplier-documents-target="dropzone"]')
    expect(page).to have_css('[data-supplier-documents-target="filters"].items-end')

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
    category_select = find('[data-supplier-documents-target="categorySelect"]', visible: :all)
    category_dropdown = category_select.find(:xpath, '..')
    category_dropdown.find('button[aria-haspopup="listbox"]').click
    category_dropdown.find('[role="option"]', text: 'Contracts', exact_text: true).click
    expect(category_select.value).to be_present
    expect(page).to have_css('[data-supplier-documents-target="card"]:not(.hidden)', count: 1)
    expect(page).to have_css('[data-supplier-documents-target="range"]', text: 'Showing 1–1 of 1')
  end

  scenario 'uploads multiple files from the inline drop zone without opening a new page' do
    visit admin_supplier_path(supplier, tab: 'documents')

    Tempfile.create(['supplier-sample', '.pdf']) do |first|
      Tempfile.create(['supplier-extra', '.pdf']) do |second|
        [first, second].each do |file|
          file.write('%PDF-1.4 example document')
          file.flush
        end

        find('[data-supplier-documents-target="uploadInput"]', visible: :all)
          .attach_file([first.path, second.path])
        expect(page).to have_css('[data-supplier-documents-target="uploadSelection"]:not(.hidden)')
        expect(page).to have_css('[data-supplier-documents-target="uploadCount"]', text: '2 file(s) selected')

        find('[data-supplier-documents-target="uploadSubmit"]').click

        expect(page).to have_css('[data-supplier-documents-target="card"]', count: 2)
        expect(page).to have_css('[data-supplier-documents-target="dropzone"]')
      end
    end
  end

  scenario 'accepts files dropped directly on the upload area' do
    visit admin_supplier_path(supplier, tab: 'documents')

    page.execute_script(<<~JS)
      const transfer = new DataTransfer()
      transfer.items.add(new File(["%PDF-1.4 demo"], "dropped-document.pdf", { type: "application/pdf" }))
      const dropzone = document.querySelector('[data-supplier-documents-target="dropzone"]')
      dropzone.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: transfer }))
    JS

    expect(page).to have_css('[data-supplier-documents-target="uploadSelection"]:not(.hidden)')
    expect(page).to have_css('[data-supplier-documents-target="uploadNames"]', text: 'dropped-document.pdf')

    find('[data-supplier-documents-target="uploadSubmit"]').click

    expect(page).to have_css('[data-supplier-documents-target="card"]', count: 1)
    expect(page).to have_text('dropped-document.pdf')
  end

  scenario 'keeps all document cards equally sized with long file names and descriptions' do
    add_file('Short.pdf')
    long_filename = 'supplier-contract-' * 8
    add_file("#{long_filename}.pdf")
    add_file('Medium name.pdf')

    attachment = supplier.documents.attachments.order(:id).last
    attachment.blob.update!(
      metadata: attachment.blob.metadata.merge(
        'custom' => { 'supplier_description' => 'Long description ' * 40 }
      )
    )

    visit admin_supplier_path(supplier, tab: 'documents')

    expect(page).to have_css('article[data-supplier-documents-target="card"]', count: 3)
    sizes = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('article[data-supplier-documents-target="card"]'))
        .map((card) => ({
          height: card.getBoundingClientRect().height,
          width: card.getBoundingClientRect().width
        }))
    JS
    expect(sizes.pluck('height').uniq.size).to eq(1)
    expect(sizes.pluck('width').uniq.size).to eq(1)
    expect(sizes.first['height']).to eq(144)

    select_document('Short.pdf')
    expect(page).to have_css('[data-supplier-documents-target="dialog"]:not(.hidden)')
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
