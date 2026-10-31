require 'rails_helper'

RSpec.describe 'Admin suppliers', type: :request do
  let(:user) { create(:user, :english) }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  let(:organization) { create(:organization) }
  let(:currency) { create(:currency) }

  def supplier_attributes
    attributes_for(:supplier).merge(currency_id: currency.id)
  end

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: admin_role)
    sign_in user
  end

  it 'does not expose another organization suppliers' do
    foreign_supplier = create(:supplier, organization: create(:organization), name: 'Foreign Supplier')
    get admin_suppliers_path
    expect(response.body).not_to include('Foreign Supplier')

    get admin_supplier_path(foreign_supplier)
    expect(response).to have_http_status(:not_found)
  end

  it 'assigns the organization on creation regardless of submitted ownership' do
    foreign_organization = create(:organization)
    post admin_suppliers_path,
         params: { supplier: supplier_attributes.merge(organization_id: foreign_organization.id) }

    expect(Supplier.order(:id).last.organization).to eq(organization)
  end

  it 'rejects changes to suppliers owned by another organization' do
    foreign_supplier = create(:supplier, organization: create(:organization))
    original_name = foreign_supplier.name

    patch admin_supplier_path(foreign_supplier), params: { supplier: { name: 'Unauthorized' } }
    expect(response).to have_http_status(:not_found)
    expect(Supplier.with_deleted.find(foreign_supplier.id).name).to eq(original_name)

    sign_in user
    delete admin_supplier_path(foreign_supplier)
    expect(response).to have_http_status(:not_found)
    persisted = Supplier.with_deleted.find(foreign_supplier.id)
    expect(persisted).to have_attributes(name: original_name, deleted_at: nil)
  end

  it 'renders the shared mascot loader and enables it for supplier actions' do
    create(:supplier, organization:)

    get admin_suppliers_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    loader = document.at_css('#admin-action-loader[data-controller="admin-action-loader"]')
    expect(loader).to be_present
    expect(loader['hidden']).not_to be_nil
    expect(loader.at_css('img[src*="deltin/waving"]')).to be_present
    expect(document.at_css('thead[data-loading-scope="true"]')).to be_present
    expect(document.at_css('a[data-loading-message][href*="/suppliers/"]')).to be_present
    expect(document.at_css('form[data-loading-message]')).to be_present
  end

  it 'uses the short back label and the existing loader on supplier navigation' do
    supplier = create(:supplier, organization:)
    expect(I18n.t('admin.suppliers.show.back', locale: :es)).to eq('Volver')

    get new_admin_supplier_path
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    back = document.at_css("a[href='#{admin_suppliers_path}'][data-loading-message]")
    expect(back).to be_present
    expect(back['data-loading-message']).to eq(I18n.t('admin.action_loader.returning'))

    get admin_supplier_path(supplier)
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('[data-controller="supplier-dossier"][data-loading-scope="true"]')).to be_present
    expect(document.at_css("a[href='#{admin_suppliers_path}'][data-loading-message]")).to be_present
    expect(document.at_css("a[href='#{edit_admin_supplier_path(supplier)}'][data-loading-message]")).to be_present
  end

  it 'makes the supplier page-size and row actions available with the Deltin loader' do
    create(:supplier, organization:)
    get admin_suppliers_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#admin-action-loader[data-controller="admin-action-loader"]')).to be_present
    expect(document.at_css('a[data-loading-message][href*="/suppliers/"]')).to be_present
    expect(document.at_css('form[data-loading-message]')).to be_present
  end

  it 'subscribes the supplier list to organization-specific Turbo updates' do
    get admin_suppliers_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    stream = document.at_css('turbo-cable-stream-source[signed-stream-name]')
    expected_stream = Turbo::StreamsChannel.signed_stream_name("suppliers_catalog_#{organization.id}")

    expect(document.css('turbo-cable-stream-source').pluck('signed-stream-name'))
      .to include(expected_stream)
    expect(stream).to be_present
  end

  it 'keeps sort and page-size parameters in the supplier filter form' do
    get admin_suppliers_path, params: { sort: 'name', direction: 'desc', per_page: 5 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="sort"')
    expect(response.body).to include('name="direction"')
    expect(response.body).to include('name="per_page"')
    expect(response.body).to include('data-controller="supplier-search"')
  end

  it 'renders supplier filter dropdowns without radio buttons' do
    get admin_suppliers_path, params: { status: 'active' }

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    dropdowns = document.css('details[data-controller~="supplier-dropdown"]').select do |dropdown|
      dropdown.at_css('input[data-supplier-dropdown-target="value"]')
    end

    expect(dropdowns).not_to be_empty
    dropdowns.each do |dropdown|
      expect(dropdown.css('input[type="radio"]')).to be_empty
      expect(dropdown.at_css('input[type="hidden"][data-supplier-dropdown-target="value"]')).to be_present
      expect(dropdown.css('[role="listbox"] button[role="option"]')).not_to be_empty
    end

    status = dropdowns.find { |dropdown| dropdown.at_css('input[name="status"]') }
    expect(status.at_css('input[name="status"]')['value']).to eq('active')
    expect(status.at_css('button[data-option-value="active"]')['aria-selected']).to eq('true')
  end

  it 'broadcasts a refresh after a supplier is created' do
    expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
      .with("suppliers_catalog_#{organization.id}")

    post admin_suppliers_path, params: { supplier: supplier_attributes }

    expect(response).to redirect_to(admin_suppliers_path)
  end

  it 'archives and restores a supplier as inactive without deleting its records' do
    supplier = create(:supplier, organization:)
    contact = supplier.contacts.create!(name: 'Keep me', primary: true)
    delete admin_supplier_path(supplier)
    expect(response).to have_http_status(:redirect)
    expect(supplier.reload.deleted_at).to be_present

    patch restore_admin_supplier_path(supplier)
    expect(response).to have_http_status(:redirect)
    expect(supplier.reload).to be_inactive
    expect(supplier.deleted_at).to be_nil
    expect(contact.reload.name).to eq('Keep me')
  end

  it 'refuses archiving while a purchase order remains open' do
    supplier = create(:supplier, organization:)
    allow_any_instance_of(Supplier).to receive(:archivable?).and_return(false)
    delete admin_supplier_path(supplier)

    expect(response).to redirect_to(admin_supplier_path(supplier))
    expect(supplier.reload.deleted_at).to be_nil
  end

  it 'requires authentication' do
    sign_out user
    get admin_suppliers_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it 'denies authenticated non-administrators' do
    sign_out user
    sign_in create(:user)
    get admin_suppliers_path
    expect(response).to have_http_status(:forbidden)
  end

  it 'renders the new supplier form' do
    get new_admin_supplier_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('admin.suppliers.new.title', locale: :en))
  end

  it 'hides status on creation and always creates an active supplier' do
    get new_admin_supplier_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('name="supplier[status]"')

    post admin_suppliers_path, params: { supplier: supplier_attributes.merge(status: 'inactive') }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(Supplier.order(:id).last).to be_active
  end

  it 'creates nested supplier contacts as active regardless of submitted status' do
    attributes = supplier_attributes.merge(
      contacts_attributes: { '0' => { name: 'Operations', active: '0' } }
    )

    post admin_suppliers_path, params: { supplier: attributes }

    expect(response).to redirect_to(admin_suppliers_path)
    expect(Supplier.order(:id).last.contacts.first).to be_active
  end

  it 'accepts currency and country references for a supplier and its fiscal address' do
    country = create(:country, iso_alpha2: 'MX')
    address_attributes = attributes_for(:address).except(:country).merge(
      country_id: country.id, purpose: 'fiscal'
    )
    attributes = supplier_attributes.merge(
      currency_id: currency.id,
      addresses_attributes: { '0' => address_attributes }
    )

    post admin_suppliers_path, params: { supplier: attributes }

    expect(response).to redirect_to(admin_suppliers_path)
    created = Supplier.order(:id).last
    expect(created.currency).to eq(currency)
    expect(created.addresses.first.country).to eq(country)
  end

  it 'renders the edit form for an existing supplier' do
    supplier = create(:supplier, organization:, name: 'Supplier to Edit')

    get edit_admin_supplier_path(supplier)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Supplier to Edit')
  end

  it 'lists, filters and excludes deleted suppliers' do
    create(:supplier, organization:, name: 'Visible Supplier')
    create(:supplier, :deleted, organization:, name: 'Deleted Supplier')

    get admin_suppliers_path, params: { search: 'Visible' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Visible Supplier')
    expect(response.body).not_to include('Deleted Supplier')
  end

  it 'filters by status and sorts by name' do
    create(:supplier, organization:, name: 'Zulu Supplier', status: :inactive)
    create(:supplier, organization:, name: 'Alpha Supplier', status: :active)

    get admin_suppliers_path, params: { status: 'active', sort: 'name', direction: 'asc' }

    rows = Nokogiri::HTML(response.body).css('tbody tr')
    expect(rows.map { |row| row.at_css('td:first-child p.font-semibold')&.text&.strip }).to eq(['Alpha Supplier'])
  end

  it 'changes page size without an Apply button and keeps filtering and ordering parameters' do
    create(:supplier, organization:, name: 'Alpha Page Size')

    get admin_suppliers_path, params: {
      search: 'Alpha', status: 'active', sort: 'name', direction: 'desc', per_page: 25
    }

    document = Nokogiri::HTML(response.body)
    form = document.at_css('#supplier-pagination-form')
    expect(form).to be_present
    expect(form['data-controller']).to eq('supplier-page-size')
    expect(form['data-action']).to include('change->supplier-page-size#apply')
    expect(form['data-turbo-frame']).to eq('_top')
    expect(form.at_css('select[name="per_page"] option[value="25"][selected]')).to be_present
    expect(form.at_css('button[type="submit"]')).to be_nil
    expect(form.at_css('input[name="search"]')['value']).to eq('Alpha')
    expect(form.at_css('input[name="sort"]')['value']).to eq('name')
    expect(form.at_css('input[name="direction"]')['value']).to eq('desc')
  end

  it 'renders the original Deltin page-size loader and keeps the selector at the far left' do
    create(:supplier, organization:)

    get admin_suppliers_path

    document = Nokogiri::HTML(response.body)
    loader = document.at_css('#supplier-page-size-loader')
    expect(loader).to be_present
    expect(loader['aria-hidden']).to eq('true')
    expect(loader.at_css('img.animate-pulse')).to be_present
    expect(loader.css('.deltin-tail-loader__runner, .deltin-tail-loader__dizzy')).to be_empty

    form = document.at_css('#supplier-pagination-form')
    footer_left = form.parent
    range = footer_left.at_css('p[aria-live="polite"]')
    expect(range).to be_present
    expect(footer_left.element_children.index(form)).to be < footer_left.element_children.index(range)
  end

  it 'shows 25 or 50 suppliers when requested' do
    create_list(:supplier, 26, organization:)

    get admin_suppliers_path, params: { per_page: 25 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(25)

    get admin_suppliers_path, params: { per_page: 50 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(26)
  end

  it 'preserves archive mode when clearing one active filter' do
    get admin_suppliers_path, params: { archived: '1', status: 'inactive', per_page: 25 }

    document = Nokogiri::HTML(response.body)
    links = document.css('#supplier_active_filters a[href]')
    expect(links.any? { |link| link['href'].include?('archived=1') }).to be(true)
  end

  it 'distinguishes empty catalog, filtered results and empty archives' do
    get admin_suppliers_path
    expect(response.body).to include('No suppliers yet')

    get admin_suppliers_path, params: { search: 'NothingMatchedThisSupplier' }
    expect(response.body).to include('No matching suppliers')

    get admin_suppliers_path, params: { archived: '1' }
    expect(response.body).to include('No archived suppliers')
  end

  it 'uses top-level navigation and a compact page window for large supplier lists' do
    create_list(:supplier, 55, organization:)

    get admin_suppliers_path, params: { per_page: 5, page: 6 }

    document = Nokogiri::HTML(response.body)
    nav = document.at_css('nav[aria-label="Supplier pagination"]')
    expect(nav).to be_present
    expect(nav.css('a[data-turbo-frame="_top"]')).not_to be_empty
    expect(nav.css('a').size).to be <= 9
    expect(nav.text).to include('…')
  end

  it 'does not paginate 10 or fewer and paginates 11+' do
    create_list(:supplier, 10, organization:)
    get admin_suppliers_path
    expect(response.body).not_to include('aria-label="Pagination"')

    create(:supplier, organization:)
    get admin_suppliers_path, params: { per_page: 5 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(5)
    expect(response.body).to include('supplier-pagination-form')
  end

  it 'rounds up the page count for supplier broadcasts' do
    create_list(:supplier, 11, organization:)

    get admin_suppliers_path

    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(10)
    expect(response.body).to include('supplier-pagination-form')
  end

  it 'supports 10 and 15 records per page' do
    create_list(:supplier, 16, organization:)
    get admin_suppliers_path, params: { per_page: 10 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(10)

    get admin_suppliers_path, params: { per_page: 15 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(15)
  end

  it 'shows a supplier and rejects deleted records' do
    supplier = create(:supplier, organization:, name: 'Supplier Details')
    get admin_supplier_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Supplier Details')

    deleted = create(:supplier, :deleted, organization:)
    get admin_supplier_path(deleted)
    expect(response).to have_http_status(:not_found)
  end

  it 'creates, updates and soft deletes with SweetAlert feedback and Noticed' do
    expect do
      post admin_suppliers_path, params: { supplier: supplier_attributes }
    end.to change(Supplier, :count).by(1)
                                   .and change { user.notifications.count }.by(1)

    expect(response).to redirect_to(admin_suppliers_path)
    expect(flash[:swal_message]).to eq('Supplier created successfully')

    supplier = Supplier.order(:id).last

    expect do
      patch admin_supplier_path(supplier), params: { supplier: { name: 'Updated Supplier' } }
    end.to change { user.notifications.count }.by(1)

    expect(response).to redirect_to(admin_suppliers_path)
    expect(flash[:swal_message]).to eq('Supplier updated successfully')
    expect(supplier.reload.name).to eq('Updated Supplier')

    expect do
      delete admin_supplier_path(supplier)
    end.to change { user.notifications.count }.by(1)

    expect(response).to redirect_to(admin_suppliers_path)
    expect(flash[:swal_message]).to eq('Supplier deleted successfully')
    expect(supplier.reload.deleted_at).to be_present
  end

  it 'returns to the general dossier tab when updated from general information' do
    supplier = create(:supplier, organization:)

    get admin_supplier_path(supplier, tab: 'general')
    expect(response.body).to include('return_to=general')

    get edit_admin_supplier_path(supplier, return_to: 'general')
    expect(response.body).to include('name="return_to"')
    expect(response.body).to include('value="general"')
    expect(response.body).to include(admin_supplier_path(supplier, tab: 'general'))

    patch admin_supplier_path(supplier), params: { return_to: 'general', supplier: { name: 'Updated from dossier' } }
    expect(response).to redirect_to(admin_supplier_path(supplier, tab: 'general'))
    expect(supplier.reload.name).to eq('Updated from dossier')
  end

  it 'preserves the general dossier origin after an invalid update' do
    supplier = create(:supplier, organization:)

    patch admin_supplier_path(supplier), params: { return_to: 'general', supplier: { name: '' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('name="return_to"')
    expect(response.body).to include('value="general"')
  end

  it 'renders grouped general information and informative empty states' do
    supplier = create(:supplier, organization:, email: nil, phone: nil, responsible_user: nil, notes: nil)

    get admin_supplier_path(supplier, tab: 'general')

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    panel = document.at_css('#supplier-dossier-general')
    expect(panel.css('h3').size).to eq(3)
    expect(panel.text).to include(I18n.t('admin.supplier_general_layout.phone_missing', locale: :en))
    expect(panel.text).to include(I18n.t('admin.supplier_general_layout.email_missing', locale: :en))
    expect(panel.text).to include(I18n.t('admin.supplier_general_layout.responsible_missing', locale: :en))
  end

  it 'renders supplier tags as individual chips' do
    supplier = create(:supplier, organization:, tags: %w[Priority Distribution])

    get admin_supplier_path(supplier, tab: 'general')

    panel = Nokogiri::HTML(response.body).at_css('#supplier-dossier-general')
    expect(panel.css('span.rounded-full').map { |chip| chip.text.squish }).to include('Priority', 'Distribution')
  end

  it 'places the address management link beside the heading and the search below the filters' do
    supplier = create(:supplier, organization:)

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(response).to have_http_status(:ok)
    section = Nokogiri::HTML(response.body).at_css('#supplier-dossier-addresses')
    title_row = section.at_css('[data-supplier-addresses-title-row]')
    toolbar = section.at_css('[data-supplier-addresses-toolbar]')
    filters = toolbar.at_css('[data-supplier-addresses-filters]')
    search_row = toolbar.at_css('[data-supplier-addresses-search-row]')

    expect(title_row.at_css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_present
    expect(title_row.at_css('input[type="search"]')).to be_nil
    expect(filters.css('[data-supplier-addresses-target="filter"]')).not_to be_empty
    expect(filters.next_element).to eq(search_row)
    expect(search_row.at_css('input[data-supplier-addresses-target="search"]')).to be_present
    expect(search_row.at_css('input')&.[]('data-action')).to eq('input->supplier-addresses#search')
  end

  it 'hides the address management actions when the user has only viewing access' do
    supplier = create(:supplier, organization:)
    allow_any_instance_of(SupplierPolicy).to receive(:manage_addresses?).and_return(false)

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(response).to have_http_status(:ok)
    panel = Nokogiri::HTML(response.body).at_css('#supplier-dossier-addresses')
    expect(panel.at_css("a[href='#{admin_supplier_addresses_path(supplier)}']")).to be_nil
    expect(panel.css('[data-supplier-addresses-target="emptyAction"]')).to be_empty
    expect(panel.at_css('input[data-supplier-addresses-target="search"]')).to be_present
  end

  it 'provides a distinct address search empty state with translated title and description' do
    supplier = create(:supplier, organization:)

    get admin_supplier_path(supplier, tab: 'addresses')

    expect(response).to have_http_status(:ok)
    panel = Nokogiri::HTML(response.body).at_css('#supplier-dossier-addresses')
    expect(panel['data-supplier-addresses-empty-title-no-results-value'])
      .to eq(I18n.t('admin.supplier_dossier.address_cards.no_results_title', locale: :en))
    expect(panel['data-supplier-addresses-empty-no-results-value'])
      .to eq(I18n.t('admin.supplier_dossier.address_cards.no_results_description', locale: :en))
    expect(panel.at_css('[data-supplier-addresses-target="emptyTitle"]')).to be_present
    expect(panel.at_css('[data-supplier-addresses-target="emptyText"]')).to be_present
    expect(panel.at_css('[data-supplier-addresses-target="emptyAction"]')).to be_present
  end

  it 'renders validation errors when creating an invalid supplier' do
    post admin_suppliers_path, params: { supplier: { code: '', name: '' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('name')
  end

  it 'renders the duplicate error when the database rejects a create' do
    allow_any_instance_of(Supplier).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    post admin_suppliers_path, params: { supplier: supplier_attributes }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.suppliers.errors.duplicate', locale: :en))
  end

  it 'renders the duplicate error when the database rejects an update' do
    supplier = create(:supplier, organization:)
    allow_any_instance_of(Supplier).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)

    patch admin_supplier_path(supplier), params: { supplier: { name: 'Conflicting Supplier' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t('admin.suppliers.errors.duplicate', locale: :en))
    expect(supplier.reload.name).not_to eq('Conflicting Supplier')
  end

  it 're-renders the edit form when an update fails validation' do
    supplier = create(:supplier, organization:, name: 'Unchanged Supplier')

    patch admin_supplier_path(supplier), params: { supplier: { name: '' } }

    expect(response).to have_http_status(:unprocessable_content)
    assert_select 'input[name="supplier[name]"]'
    expect(response.body).to include('rose-500')
    expect(supplier.reload.name).to eq('Unchanged Supplier')
  end
end
