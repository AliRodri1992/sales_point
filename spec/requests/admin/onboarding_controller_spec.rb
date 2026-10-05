# frozen_string_literal: true

RSpec.describe Admin::OnboardingController, type: :request do
  let(:user) { create(:user) }
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let(:organization) { create(:organization, :with_settings) }

  before do
    create(:user_role, user:, system_role: role)
    create(:organization_membership, user:, organization:)
    create(:employee, organization:, email: user.email)
    create(:branch, organization:)
    sign_in user
  end

  it 'shows onboarding and initializes pending organizations' do
    get admin_onboarding_path

    expect(response).to have_http_status(:ok)
    expect(organization.reload.onboarding_status).to eq('in_progress')
    expect(organization.onboarding_audits.where(action: 'started')).to exist
  end

  it 'renders the update form when a step cannot be saved' do
    allow(Onboarding::StepUpdater).to receive(:call).and_return(false)

    patch admin_onboarding_path(step: 1), params: { organization: {} }

    expect(response).to have_http_status(:unprocessable_content)
    expect(flash.now[:swal_icon]).to eq(I18n.t('admin.onboarding.incomplete.icon'))
  end

  it 'redirects to the next step after a successful update' do
    allow(Onboarding::StepUpdater).to receive(:call).and_return(true)

    patch admin_onboarding_path(step: 2), params: {}

    expect(response).to redirect_to(admin_onboarding_path(step: 3))
  end

  it 'redirects to the dashboard after completing the final step' do
    allow(Onboarding::StepUpdater).to receive(:call).and_return(true)

    patch admin_onboarding_path(step: 5), params: {}

    expect(response).to redirect_to(admin_dashboard_path)
    expect(flash[:swal_message]).to eq(I18n.t('admin.onboarding.completed'))
  end

  it 'normalizes an invalid step to the first step' do
    allow(Onboarding::StepUpdater).to receive(:call).and_return(false)

    patch admin_onboarding_path(step: 99), params: {}

    expect(response).to have_http_status(:unprocessable_content)
  end
end
