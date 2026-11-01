# frozen_string_literal: true

RSpec.describe Onboarding::PaymentUpdater, type: :service do
  def payment_params(method)
    ActionController::Parameters.new(payment: { method: })
  end

  def create_integration(organization, **attributes)
    PaymentIntegration.create!({ organization:, provider: 'card', status: :pending }.merge(attributes))
  end

  it 'returns false when organization settings are missing' do
    organization = create(:organization)

    expect(described_class.call(organization, payment_params('cash'))).to be(false)
  end

  it 'deactivates existing integrations for cash payments' do
    organization = create(:organization, :with_settings)
    integration = create_integration(organization)

    expect(described_class.call(organization, payment_params('cash'))).to be(true)

    expect(integration.reload.status).to eq('inactive')
    expect(integration.deleted_at).to be_present
    expect(organization.organization_settings.first.reload.payment_method).to eq('cash')
  end

  it 'creates a pending integration for non-cash payments' do
    organization = create(:organization, :with_settings)

    expect(described_class.call(organization, payment_params('card'))).to be(true)

    integration = organization.payment_integrations.first
    expect(integration.provider).to eq('card')
    expect(integration.status).to eq('pending')
    expect(integration.deleted_at).to be_nil
  end

  it 'reactivates an existing integration when its provider is selected' do
    organization = create(:organization, :with_settings)
    integration = create_integration(
      organization,
      status: :inactive,
      deleted_at: Time.current
    )

    expect(described_class.call(organization, payment_params('card'))).to be(true)

    expect(integration.reload.status).to eq('pending')
    expect(integration.deleted_at).to be_nil
  end
end
