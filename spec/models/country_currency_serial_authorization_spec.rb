# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Currency, inventory serial and authorization boundaries', type: :model do
  describe InventorySerial do
    it 'rejects a serial number associated with another organization' do
      serial = described_class.new(organization_id: 1)
      allow(serial).to receive(:inventory_lot).and_return(double(organization_id: 2))
      serial.send(:consistent_organization)
      expect(serial.errors[:inventory_lot]).not_to be_empty
    end

    it 'allows matching organization inventory lots' do
      serial = described_class.new(organization_id: 1)
      allow(serial).to receive(:inventory_lot).and_return(double(organization_id: 1))
      serial.send(:consistent_organization)
      expect(serial.errors[:inventory_lot]).to be_empty
    end
  end

  describe CountryCurrency do
    it 'rejects marking an inactive currency assignment as primary' do
      record = described_class.new(is_primary: true, active: false)
      record.send(:primary_must_be_active)
      expect(record.errors[:is_primary]).not_to be_empty
    end

    it 'allows a primary assignment when active' do
      record = described_class.new(is_primary: true, active: true)
      record.send(:primary_must_be_active)
      expect(record.errors[:is_primary]).to be_empty
    end

    it 'skips uniqueness checks when the assignment is not primary' do
      record = described_class.new(is_primary: false)
      record.send(:only_one_primary_currency)
      expect(record.errors[:is_primary]).to be_empty
    end

    it 'rejects a second primary currency in the same country' do
      record = described_class.new(country_id: 1, is_primary: true)
      relation = double
      allow(relation).to receive(:where).and_return(relation)
      allow(relation).to receive(:not).and_return(relation)
      allow(relation).to receive(:exists?).and_return(true)
      allow(described_class).to receive(:where).and_return(relation)
      record.send(:only_one_primary_currency)
      expect(record.errors[:is_primary]).not_to be_empty
    end
  end

  describe UserPolicy do
    it 'denies ordinary users access to user administration' do
      policy = described_class.new(double(admin?: false), nil)
      expect(policy.index?).to be(false)
      expect(policy.create?).to be(false)
    end

    it 'allows administrators to view and update users' do
      policy = described_class.new(double(admin?: true), nil)
      expect(policy.show?).to be(true)
      expect(policy.update?).to be(true)
    end

    it 'handles a missing user without granting permissions' do
      policy = described_class.new(nil, nil)
      expect(policy.destroy?).to be_nil
    end
  end

  describe Authentication::LanguageSelectorComponent do
    it 'uses its brand hover default' do
      selector = described_class.new(languages: [], current_language: nil)
      expect(selector.send(:hover_class)).to eq('language-option-brand')
    end

    it 'supports the blue hover variant' do
      selector = described_class.new(languages: [], current_language: nil, hover: :blue)
      expect(selector.send(:hover_class)).to eq('language-option-blue')
    end
  end
end
