# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentIntegration, type: :model do
  subject(:integration) { build(:payment_integration) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:status) }

    it 'accepts a valid integration' do
      expect(integration).to be_valid
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
    it do
      expect(described_class).to define_enum_for(:provider).with_values(card: 'card', qr: 'qr')
    end

    it do
      expect(described_class).to define_enum_for(:status)
        .with_values(pending: 'pending', active: 'active', inactive: 'inactive')
    end
  end
end
