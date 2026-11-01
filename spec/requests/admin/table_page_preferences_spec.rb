require 'rails_helper'

RSpec.describe 'Admin table page preferences', type: :request do
  let(:user) { create(:user, :english) }
  let(:other_user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  before do
    create(:organization_membership, user:, organization:)
    create(:user_role, user:, system_role: create(:system_role, code: 'administrator', role_type: :system))
    create(:organization_setting, organization:, default_table_page_size: 25)
    sign_in user
  end

  it 'uses the organization default when no override exists' do
    create_list(:supplier, 28, organization:)

    get admin_suppliers_path
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(25)
  end

  it 'saves the chosen size and applies it on subsequent visits' do
    create_list(:supplier, 12, organization:)
    patch admin_table_page_preference_path('suppliers'), params: { per_page: 5 }

    expect(response).to have_http_status(:no_content)
    expect(user.table_page_preferences.find_by!(organization:, table_key: 'suppliers').per_page).to eq(5)

    get admin_suppliers_path
    expect(Nokogiri::HTML(response.body).css('tbody tr').size).to eq(5)
  end

  it 'uses a URL page size only for that request and does not persist a GET request' do
    create(:table_page_preference, user:, organization:, per_page: 5)

    get admin_suppliers_path, params: { per_page: 10 }
    expect(response).to have_http_status(:ok)
    expect(user.table_page_preferences.find_by!(organization:, table_key: 'suppliers').per_page).to eq(5)
  end

  it 'isolates overrides by table and user' do
    patch admin_table_page_preference_path('suppliers'), params: { per_page: 5 }
    patch admin_table_page_preference_path('products'), params: { per_page: 50 }

    expect(user.table_page_preferences.where(organization:).pluck(:table_key, :per_page)).to contain_exactly(
      ['suppliers', 5], ['products', 50]
    )
    expect(other_user.table_page_preferences.count).to eq(0)
  end

  it 'rejects invalid keys and sizes' do
    patch admin_table_page_preference_path('unknown'), params: { per_page: 10 }
    expect(response).to have_http_status(:unprocessable_content)

    patch admin_table_page_preference_path('suppliers'), params: { per_page: 500 }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.table_page_preferences.count).to eq(0)
  end

  it 'does not accept an organization identifier from the requester' do
    patch admin_table_page_preference_path('suppliers'),
          params: { per_page: 15, organization_id: other_organization.id }

    expect(response).to have_http_status(:no_content)
    preference = user.table_page_preferences.sole
    expect(preference.organization).to eq(organization)
  end

  it 'requires authentication' do
    sign_out user
    patch admin_table_page_preference_path('suppliers'), params: { per_page: 25 }
    expect(response).to redirect_to(new_user_session_path)
  end
end
