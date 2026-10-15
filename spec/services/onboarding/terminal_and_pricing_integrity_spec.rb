# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Terminal onboarding and mutation protection branches', type: :service do
  describe Onboarding::TerminalsUpdater do
    it 'does not attempt updates when terminal list is empty' do
      organization = double('Organization')
      branches = double
      allow(branches).to receive(:not_deleted).and_return(branches)
      allow(branches).to receive(:where).and_return(branches)
      allow(branches).to receive(:first).and_return(nil)
      allow(organization).to receive(:branches).and_return(branches)
      expect(described_class.call(organization, {}, terminals: [])).to be(false)
    end

    it 'uses provided terminal names for successful updates' do
      terminal = double
      allow(terminal).to receive(:assign_attributes)
      allow(terminal).to receive(:save!).and_return(true)
      params = { terminal_names: { '0' => 'Checkout' } }
      expect(described_class.call(double, params, terminals: [terminal])).to be(true)
      expect(terminal).to have_received(:assign_attributes).with(name: 'Checkout')
    end

    it 'returns false as soon as a terminal cannot be saved' do
      terminal = double
      allow(terminal).to receive(:assign_attributes)
      allow(terminal).to receive(:save!).and_return(false)
      params = { terminal_names: { '0' => 'Checkout' } }
      expect(described_class.call(double, params, terminals: [terminal])).to be(false)
    end

    it 'falls back to localized default names' do
      instance = described_class.new(double, {}, [])
      expect(instance.send(:terminal_name, 0)).to eq(I18n.t('registration.initial_terminal_name', number: 1))
    end
  end

  describe SupplierProductPrice do
    it 'prevents changes to immutable supplier pricing records' do
      price = described_class.new
      expect { price.send(:prevent_changes) }.to throw_symbol(:abort)
      expect(price.errors[:base]).not_to be_empty
    end
  end
end
