# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Active organization selection', type: :request do
  let(:primary) { create(:organization) }
  let(:secondary) { create(:organization) }
  let(:admin) { create(:user, system_roles: [create(:system_role, :system, code: 'administrator')]) }

  before do
    create(:organization_membership, user: admin, organization: primary)
    create(:organization_membership, user: admin, organization: secondary)
    sign_in admin
  end

  it 'switches the user directory to the selected accessible organization' do
    first = create(:user, email: 'first-org@example.com')
    second = create(:user, email: 'second-org@example.com')
    create(:organization_membership, user: first, organization: primary)
    create(:organization_membership, user: second, organization: secondary)

    get admin_users_path
    expect(response.body).to include(first.email)
    expect(response.body).not_to include(second.email)

    patch admin_select_organization_path(secondary)
    expect(response).to redirect_to(admin_dashboard_path)

    get admin_users_path
    expect(response.body).to include(second.email)
    expect(response.body).not_to include(first.email)
  end

  it 'refuses selecting an organization without an accessible membership' do
    foreign = create(:organization)
    create(:organization_membership, user: create(:user), organization: primary)
    get admin_users_path
    expect(response).to have_http_status(:ok)
    patch admin_select_organization_path(foreign)

    expect(response).to have_http_status(:not_found)
    get admin_users_path
    expect(response).to have_http_status(:ok), "Unexpected redirect to #{response.location}"
  end
end
