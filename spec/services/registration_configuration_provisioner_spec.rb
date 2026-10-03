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
    described_class.call(organization:, params:)

    expect(organization.reload.organization_settings.count).to eq(1)
    expect(organization.branches.count).to eq(1)
    expect(organization.branches.first.terminals.count).to eq(3)
    expect(organization.payment_integrations.count).to eq(1)

    expect(organization.organization_settings.first).to have_attributes(
      currency: 'MXN',
      payment_method: 'card'
    )
  end

  it 'creates migration configuration only for migration setup' do
    migration_params = params.merge(
      setup_type: 'migration',
      terminals: '1',
      payment_integration: 'cash',
      migration_volume: 'under_500',
      migration_priority: 'inventory'
    )

    described_class.call(organization:, params: migration_params)

    expect(organization.organization_migrations.count).to eq(1)
    expect(organization.payment_integrations.count).to eq(0)

    expect(organization.organization_migrations.first).to have_attributes(
      volume: 'small',
      priority: 'inventory',
      status: 'pending'
    )
  end
end
