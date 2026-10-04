# frozen_string_literal: true

RSpec.describe 'Admin onboarding', type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization, :with_settings) }
  let!(:membership) { create(:organization_membership, organization:, user:) }
  let!(:role) do
    SystemRole.find_or_create_by!(code: 'administrator') do |system_role|
      system_role.name = 'Administrator'
      system_role.role_type = :system
      system_role.status = :active
    end
  end
  let!(:user_role) { create(:user_role, user:, system_role: role) }
  let!(:employee) { create(:employee, organization:) }
  let!(:branch) { create(:branch, organization:) }
  let!(:terminal) { create(:terminal, branch:) }

  before do
    sign_in user
  end

  it 'starts and persists onboarding progress' do
    expect(organization.onboarding_status).to eq('pending')

    get admin_onboarding_path(step: 1)

    expect(response).to have_http_status(:ok)

    organization.reload
    expect(organization).to be_onboarding_status_in_progress
    expect(organization.onboarding_current_step).to eq(1)
    expect(organization.onboarding_sections).to be_present
    expect(organization.onboarding_audits.where(action: 'started')).to exist
  end

  it 'completes the five-step flow without recreating terminals' do
    get admin_onboarding_path(step: 1)

    patch admin_onboarding_path(step: 1), params: {
      organization: {
        name: organization.name,
        tax_id: organization.tax_id,
        business_sector: organization.business_sector,
        currency: 'MXN',
        timezone: 'America/Mexico_City'
      }
    }

    expect(response).to redirect_to(admin_onboarding_path(step: 2))

    patch admin_onboarding_path(step: 2), params: {
      branch: {
        name: 'Sucursal Centro',
        phone: '5551234567',
        address_attributes: {
          id: branch.address.id,
          street: 'Av. Reforma',
          exterior_number: '100',
          interior_number: '',
          neighborhood: 'Centro',
          city: 'Cuautitlán',
          state: 'Estado de México',
          country: 'MX',
          postal_code: '54800'
        }
      }
    }

    expect(response).to redirect_to(admin_onboarding_path(step: 3))

    patch admin_onboarding_path(step: 3), params: {
      terminal_names: { '0' => 'Caja Principal' }
    }

    expect(response).to redirect_to(admin_onboarding_path(step: 4))

    patch admin_onboarding_path(step: 4), params: {
      payment: { method: 'card' }
    }

    expect(response).to redirect_to(admin_onboarding_path(step: 5))

    expect do
      patch admin_onboarding_path(step: 5)
    end.to change { Terminal.count }.by(0)

    expect(response).to redirect_to(admin_dashboard_path)

    organization.reload
    terminal.reload
    expect(organization).to be_onboarding_status_completed
    expect(organization.onboarding_completed_at).to be_present
    expect(organization.onboarding_current_step).to eq(5)
    expect(terminal.name).to eq('Caja Principal')
    expect(organization.onboarding_audits.where(action: 'completed')).to exist
  end

  it 'resets onboarding without deleting configured data' do
    organization.update!(
      onboarding_status: :completed,
      onboarding_current_step: 5,
      onboarding_completed_at: Time.current
    )

    expect do
      patch admin_onboarding_reset_path
    end.to change { organization.reload.onboarding_status }.from('completed').to('pending')

    expect(response).to redirect_to(admin_onboarding_path(step: 1))
    organization.reload

    expect(organization.onboarding_current_step).to eq(1)
    expect(organization.onboarding_completed_at).to be_nil
    expect(branch.reload).to be_persisted
    expect(terminal.reload).to be_persisted
    expect(organization.onboarding_audits.where(action: 'reset')).to exist
  end
end
