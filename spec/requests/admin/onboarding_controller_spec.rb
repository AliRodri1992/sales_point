# frozen_string_literal: true

RSpec.describe Admin::OnboardingController, type: :request do
  let(:user) { create(:user) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:organization) { create(:organization, :with_settings) }

  before do
    create(:user_role, user:, system_role: role)
    create(:organization_membership, user:, organization:)
    sign_in user
  end

  it 'shows progressive onboarding without redirecting away' do
    get admin_onboarding_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Initial Setup')
    expect(response.body).to include('Overall progress')
  end
end