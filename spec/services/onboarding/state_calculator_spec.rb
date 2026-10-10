# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Onboarding::StateCalculator, type: :service do
  let(:organization) { create(:organization) }

  describe '#call' do
    it 'returns an empty state for unsupported steps' do
      expect(described_class.new(organization, 5).call).to eq({})
    end

    it 'returns organization data and nil settings when settings are absent' do
      state = described_class.new(organization, 1).call

      expect(state['organization']).to include(
        'name' => organization.name,
        'tax_id' => organization.tax_id,
        'business_sector' => organization.business_sector
      )
      expect(state['settings']).to be_nil
    end

    it 'returns selected organization settings for the company step' do
      create(:organization_setting, organization:, currency: 'USD', timezone: 'UTC')

      state = described_class.new(organization, 1).call

      expect(state['settings']).to include('currency' => 'USD', 'timezone' => 'UTC')
    end

    it 'returns an empty branch state when the organization has no branches' do
      expect(described_class.new(organization, 2).call).to eq({})
    end

    it 'falls back to a non-deleted inactive branch and tolerates a missing address' do
      branch = create(:branch, organization:, status: false, without_address: true)

      state = described_class.new(organization, 2).call

      expect(state['branch']).to include('name' => branch.name, 'phone' => branch.phone)
      expect(state['address']).to be_nil
    end

    it 'returns the active branch and its address details' do
      branch = create(:branch, organization:)

      state = described_class.new(organization, 2).call

      expect(state['branch']['name']).to eq(branch.name)
      expect(state['address']).to include('street' => branch.address.street,
                                          'postal_code' => branch.address.postal_code)
    end

    it 'returns an empty terminal state when no branch exists' do
      expect(described_class.new(organization, 3).call).to eq({})
    end

    it 'returns active terminals indexed by position' do
      branch = create(:branch, organization:)
      terminal = create(:terminal, branch:)

      state = described_class.new(organization, 3).call

      expect(state).to eq(
        '0' => {
          'name' => terminal.name,
          'code' => terminal.code,
          'status' => terminal.status,
          'branch_id' => branch.id
        }
      )
    end

    it 'returns nil settings and an empty integrations list for the payment step' do
      state = described_class.new(organization, 4).call

      expect(state).to eq('settings' => nil, 'integrations' => [])
    end

    it 'returns payment settings and non-deleted integrations' do
      create(:organization_setting, organization:, payment_method: :card)
      integration = create(:payment_integration, organization:, provider: :card)
      create(:payment_integration, :qr, organization:, deleted_at: Time.current)

      state = described_class.new(organization, 4).call

      expect(state['settings']).to eq('payment_method' => 'card')
      expect(state['integrations']).to eq([{ 'provider' => integration.provider, 'status' => integration.status }])
    end
  end
end
