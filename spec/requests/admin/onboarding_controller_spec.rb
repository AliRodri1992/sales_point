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

  it 'uses the current progress step when no step is supplied' do
    organization.update!(onboarding_current_step: 3)
    allow(Onboarding::StepUpdater).to receive(:call).and_return(true)

    patch admin_onboarding_path, params: {}

    expect(response).to redirect_to(admin_onboarding_path(step: 4))
    expect(Onboarding::StepUpdater).to have_received(:call).with(hash_including(step: 3))
  end

  it 'treats negative and nonnumeric step values as the first step' do
    allow(Onboarding::StepUpdater).to receive(:call).and_return(true)

    %w[-2 invalid].each do |step|
      patch admin_onboarding_path(step:), params: {}
      expect(response).to redirect_to(admin_onboarding_path(step: 2))
    end
  end

  it 'does not duplicate the onboarding started audit when progress already began' do
    organization.update!(onboarding_status: :in_progress)
    get admin_onboarding_path

    expect(response).to have_http_status(:ok)
    expect(organization.onboarding_audits.where(action: 'started')).to be_empty
  end

  it 'prevents operations after the organization membership is deactivated' do
    user.organization_memberships.find_by!(organization:).update!(status: :inactive)

    get admin_onboarding_path
    expect(response).to have_http_status(:not_found).or redirect_to(new_user_session_path)

    patch admin_onboarding_path(step: 1), params: {}
    expect(response).to have_http_status(:not_found).or redirect_to(new_user_session_path)

    patch admin_onboarding_reset_path
    expect(response).to have_http_status(:not_found).or redirect_to(new_user_session_path)
    expect(organization.reload.onboarding_status).to eq('pending')
    expect(organization.onboarding_audits).to be_empty
  end
end
