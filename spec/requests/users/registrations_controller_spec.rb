# frozen_string_literal: true

RSpec.describe Users::RegistrationsController, type: :request do
  let!(:administrator) { create(:system_role, :system, code: 'administrator') }
  let!(:permission) { create(:permission, status: :active) }

  before do
    create(:system_role_permission, system_role: administrator, permission:)
  end

  let(:registration_params) do
    {
      user: {
        email: 'owner@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      },
      setup_type: 'new',
      first_name: 'Ivan',
      last_name: 'Rodriguez',
      company_name: 'Delta Retail',
      tax_id: 'ABC123456789',
      business_sector: 'grocery',
      currency: 'MXN',
      terminals: '1',
      payment_integration: 'cash',
      terms: '1'
    }
  end

  it 'creates the initial organization and signs the user in' do
    post user_registration_path, params: registration_params

    expect(response).to redirect_to(admin_dashboard_path)
    expect(User.find_by(email: 'owner@example.com').employee.organization).to be_present
    expect(Organization.count).to eq(1)
    expect(OrganizationMembership.count).to eq(1)
    expect(Branch.count).to eq(1)
    expect(Terminal.count).to eq(1)
    expect(User.find_by(email: 'owner@example.com').employee.organization.onboarding_status).to eq('pending')
  end

  it 'rolls back when terms are not accepted' do
    post user_registration_path, params: registration_params.merge(terms: '0')

    expect(response).to have_http_status(:unprocessable_content)
    expect(User.find_by(email: 'owner@example.com')).to be_nil
    expect(Organization.count).to eq(0)
  end
end
