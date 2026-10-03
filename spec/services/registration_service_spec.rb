# frozen_string_literal: true

RSpec.describe RegistrationService, type: :service do
  let(:role) { create(:system_role, :system, code: 'administrator') }
  let!(:permissions) { create_list(:permission, 3, status: :active) }
  let(:user) do
    build(:user, email: 'owner@example.com', password: 'password123', password_confirmation: 'password123')
  end
  let(:params) do
    {
      setup_type: 'new',
      first_name: 'Ivan',
      last_name: 'Rodriguez',
      company_name: 'Delta Retail',
      tax_id: 'ABC123456789',
      business_sector: 'grocery',
      currency: 'MXN',
      terminals: '2',
      payment_integration: 'cash',
      terms: '1'
    }
  end

  before do
    allow(SystemRole).to receive(:available).and_return(SystemRole.where(id: role.id))
  end

  it 'creates the initial organization atomically' do
    result = described_class.call(resource: user, params:)

    expect(result).to be_success
    expect(user.reload.employee.organization.name).to eq('Delta Retail')
    expect(user.organizations).to contain_exactly(user.employee.organization)
    expect(user.system_roles).to contain_exactly(role)
    expect(user.employee.organization.branches.count).to eq(1)
    expect(user.employee.organization.branches.first.terminals.count).to eq(2)
  end

  it 'rolls back domain records when the user is invalid' do
    user.email = nil

    result = described_class.call(resource: user, params:)

    expect(result).not_to be_success
    expect(Organization.count).to eq(0)
    expect(Employee.count).to eq(0)
    expect(OrganizationMembership.count).to eq(0)
  end

  it 'requires terms acceptance' do
    result = described_class.call(resource: user, params: params.merge(terms: '0'))

    expect(result).not_to be_success
    expect(Organization.count).to eq(0)
  end
