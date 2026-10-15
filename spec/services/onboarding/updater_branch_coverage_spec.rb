# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding updater decision paths', type: :service do
  describe Onboarding::PaymentUpdater do
    let(:organization) { double('Organization') }
    let(:params) { double(expect: { method: 'cash' }) }

    it 'returns false if settings cannot be found' do
      allow(organization).to receive(:organization_settings).and_return(double(first: nil))
      expect(described_class.call(organization, params)).to be(false)
    end

    it 'returns false when saving the payment method is unsuccessful' do
      settings = double
      allow(settings).to receive(:payment_method=)
      allow(settings).to receive(:save!).and_return(false)
      expect(described_class.call(organization, params, settings:)).to be(false)
    end

    it 'deactivates existing payment integrations for cash' do
      settings = double
      allow(settings).to receive(:payment_method=)
      allow(settings).to receive(:save!).and_return(true)
      integration = double
      allow(integration).to receive(:update!)
      allow(organization).to receive(:payment_integrations)
        .and_return(double(where: double(find_each: nil)))
      service = described_class.new(organization, params, settings)
      allow(service).to receive(:deactivate_all_payment_integrations)
      expect(service.call).to be(true)
      expect(service).to have_received(:deactivate_all_payment_integrations)
    end

    it 'activates the selected integration for noncash methods' do
      settings = double
      allow(settings).to receive(:payment_method=)
      allow(settings).to receive(:save!).and_return(true)
      other = double(expect: { method: 'card' })
      service = described_class.new(organization, other, settings)
      allow(service).to receive(:create_or_update_payment_integration)
      expect(service.call).to be(true)
      expect(service).to have_received(:create_or_update_payment_integration).with('card')
    end
  end

  describe Onboarding::BranchUpdater do
    let(:organization) { double('Organization') }
    let(:params) { double(expect: { name: 'Main' }) }

    it 'does not update when no branch is available' do
      branches = double
      allow(branches).to receive(:not_deleted).and_return(branches)
      allow(branches).to receive(:where).and_return(branches)
      allow(branches).to receive(:first).and_return(nil)
      allow(organization).to receive(:branches).and_return(branches)
      expect(described_class.call(organization, params)).to be(false)
    end

    it 'updates a branch without a nested address' do
      branch = double(save!: true, address: nil)
      allow(branch).to receive(:assign_attributes)
      expect(described_class.call(organization, params, branch:)).to be(true)
      expect(branch).to have_received(:assign_attributes).with(name: 'Main')
    end

    it 'returns the nested address save result' do
      address = double(save!: true)
      branch = double(save!: true, address:)
      allow(branch).to receive(:assign_attributes)
      expect(described_class.call(organization, params, branch:)).to be(true)
    end

    it 'returns false on failed branch save' do
      branch = double(save!: false)
      allow(branch).to receive(:assign_attributes)
      expect(described_class.call(organization, params, branch:)).to be(false)
    end
  end
end
