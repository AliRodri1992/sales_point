# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentIntegration, type: :model do
  subject(:integration) { build(:payment_integration) }

  describe 'associations' do
    it 'belongs to an organization' do
      association = described_class.reflect_on_association(:organization)

      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(integration).to be_valid
    end

    it 'requires a provider' do
      integration.provider = nil

      expect(integration).to be_invalid
      expect(integration.errors[:provider]).to be_present
    end

    it 'requires a status' do
      integration.status = nil

      expect(integration).to be_invalid
      expect(integration.errors[:status]).to be_present
    end

    it 'rejects duplicate active integrations for the same organization and provider' do
      organization = create(:organization)
      create(:payment_integration, organization:, provider: :card)
      duplicate = build(:payment_integration, organization:, provider: :card)

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:organization_id]).to be_present
    end

    it 'allows the same provider after the existing integration is soft deleted' do
      organization = create(:organization)
      existing = create(:payment_integration, organization:, provider: :card)
      existing.update!(deleted_at: Time.current)

      replacement = build(:payment_integration, organization:, provider: :card)

      expect(replacement).to be_valid
    end
  end

  describe 'enums' do
    it 'defines the supported providers' do
      expect(described_class.providers).to eq('card' => 'card', 'qr' => 'qr')
    end

    it 'defines the supported statuses' do
      expect(described_class.statuses).to eq(
        'pending' => 'pending',
        'active' => 'active',
        'inactive' => 'inactive'
      )
    end
  end
end
