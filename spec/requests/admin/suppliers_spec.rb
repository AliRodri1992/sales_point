require 'rails_helper'

RSpec.describe 'Admin suppliers', type: :request do
  let(:user) { create(:user) }
  let(:admin_role) { create(:system_role, code: 'administrator', role_type: :system) }

  before do
    create(:user_role, user:, system_role: admin_role)
    sign_in user
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

  it 'lists, filters and excludes deleted suppliers' do
    create(:supplier, name: 'Visible Supplier')
    create(:supplier, :deleted, name: 'Deleted Supplier')

    get admin_suppliers_path, params: { search: 'Visible' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Visible Supplier')
    expect(response.body).not_to include('Deleted Supplier')
  end

  it 'filters by status and sorts by name' do
    create(:supplier, name: 'Zulu Supplier', status: :inactive)
    create(:supplier, name: 'Alpha Supplier', status: :active)

    get admin_suppliers_path, params: { status: 'active', sort: 'name', direction: 'asc' }

    rows = Nokogiri::HTML(response.body).css('tbody tr')
    expect(rows.map { |row| row.css('td')[1].text.strip }).to eq(['Alpha Supplier'])
  end

  it 'does not paginate 10 or fewer and paginates 11+' do
    create_list(:supplier, 10)
    get admin_suppliers_path
    expect(response.body).not_to include('supplier-pagination-form')

    create(:supplier)
    get admin_suppliers_path, params: { per_page: 5 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(5)
    expect(response.body).to include('supplier-pagination-form')
  end

  it 'supports 10 and 15 records per page' do
    create_list(:supplier, 16)
    get admin_suppliers_path, params: { per_page: 10 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(10)

    get admin_suppliers_path, params: { per_page: 15 }
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(15)
  end

  it 'shows a supplier and rejects deleted records' do
    supplier = create(:supplier, name: 'Supplier Details')
    get admin_supplier_path(supplier)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Supplier Details')

    deleted = create(:supplier, :deleted)
    get admin_supplier_path(deleted)
    expect(response).to have_http_status(:not_found)
  end

  it 'creates, updates and soft deletes with SweetAlert feedback and Noticed' do
    expect do
      post admin_suppliers_path, params: { supplier: attributes_for(:supplier) }
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

  it 'renders validation errors' do
    post admin_suppliers_path, params: { supplier: { code: '', name: '' } }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
