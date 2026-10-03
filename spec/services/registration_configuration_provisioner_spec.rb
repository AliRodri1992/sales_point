# frozen_string_literal: true

RSpec.describe RegistrationConfigurationProvisioner, type: :service do
  let(:organization) { create(:organization) }

  let(:params) do
    {
      currency: 'MXN',
      terminals: '3_5',
      payment_integration: 'card',
      setup_type: 'new'
    }
  end

  it 'provisions the initial operational configuration' do
    expect {
      described_class.call(organization:, params:)
    }.to change(OrganizationSetting, :count).by(1)
      .and change(Branch, :count).by(1)
      .and change(Terminal, :count).by(3)
      .and change(PaymentIntegration, :count).by(1)

    expect(organization.reload.organization_settings.first).to have_attributes(
      currency: 'MXN',
      payment_method: 'card'
    )
    expect(organization.branches.first.terminals.count).to eq(3)
  end

  it 'creates migration configuration only for migration setup' do
    migration_params = params.merge(
      setup_type: 'migration',
      terminals: '1',
      payment_integration: 'cash',
      migration_volume: 'under_500',
      migration_priority: 'inventory'
    )

    expect {
      described_class.call(organization:, params: migration_params)
    }.to change(OrganizationMigration, :count).by(1)
      .and change(PaymentIntegration, :count).by(0)

    expect(organization.organization_migrations.first).to have_attributes(
      volume: 'small',
      priority: 'inventory',
      status: 'pending'
    )
  end
end
