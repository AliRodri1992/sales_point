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

  it 'preserves existing integrations when cash is selected' do
    organization = create(:organization, :with_settings)
    integration = create_integration(organization)

    expect(described_class.call(organization, payment_params('cash'))).to be(true)

    expect(integration.reload.status).to eq('pending')
    expect(integration.deleted_at).to be_nil
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
  it 'keeps an active integration active when its preference is saved again' do
    organization = create(:organization, :with_settings)
    organization.organization_settings.first.update!(payment_method: :card)
    integration = create_integration(organization, status: :active)
    expect(described_class.call(organization, payment_params('card'))).to be(true)
    expect(integration.reload.status).to eq('active')
    expect(integration.deleted_at).to be_nil
  end

  it 'rejects an unknown payment method with a validation error' do
    organization = create(:organization, :with_settings)
    settings = organization.organization_settings.first
    expect(described_class.call(organization, payment_params('unknown'), settings:)).to be(false)
    expect(settings.errors[:payment_method]).to be_present
    expect(settings.reload.payment_method).to eq('cash')
  end
end
