# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Onboarding::CompanyUpdater, type: :service do
  describe '.call' do
    it 'returns false when the organization has no settings record' do
      organization = create(:organization)

      expect(
        described_class.call(
          organization,
          ActionController::Parameters.new(
            organization: { name: 'Updated Company', currency: 'MXN', timezone: 'America/Mexico_City' }
          )
        )
      ).to be(false)
    end

    it 'updates organization and settings attributes together' do
      organization = create(:organization, :with_settings)
      settings = organization.organization_settings.first
      params = ActionController::Parameters.new(
        organization: {
          name: 'Updated Company',
          tax_id: 'ABC123456AB1',
          business_sector: 'fashion',
          currency: 'MXN',
          timezone: 'America/Mexico_City'
        }
      )

      expect(described_class.call(organization, params)).to be(true)
      expect(organization.reload).to have_attributes(
        name: 'Updated Company',
        tax_id: 'ABC123456AB1',
        business_sector: 'fashion'
      )
      expect(settings.reload).to have_attributes(
        currency: 'MXN',
        timezone: 'America/Mexico_City'
      )
    end

    it 'updates the explicitly supplied settings record' do
      organization = create(:organization, :with_settings)
      settings = organization.organization_settings.first
      params = ActionController::Parameters.new(
        organization: {
          name: organization.name,
          tax_id: organization.tax_id,
          business_sector: organization.business_sector,
          currency: 'USD',
          timezone: 'UTC'
        }
      )

      expect(described_class.call(organization, params, settings:)).to be(true)
      expect(settings.reload).to have_attributes(currency: 'USD', timezone: 'UTC')
    end

    it 'raises a validation error rather than silently accepting invalid company data' do
      organization = create(:organization, :with_settings)
      params = ActionController::Parameters.new(
        organization: { name: '', currency: 'MXN', timezone: 'America/Mexico_City' }
      )

      expect { described_class.call(organization, params) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
