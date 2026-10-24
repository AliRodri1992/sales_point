# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier contact ownership and return routing', type: :model do
  describe Supplier do
    it 'does not require a responsible user if none is assigned' do
      supplier = described_class.new
      supplier.send(:responsible_user_in_organization)
      expect(supplier.errors[:responsible_user]).to be_empty
    end

    it 'rejects a responsible user without active organization membership' do
      organization = create(:organization)
      responsible = create(:user)
      supplier = described_class.new(organization:, responsible_user: responsible)
      supplier.send(:responsible_user_in_organization)
      expect(supplier.errors[:responsible_user]).not_to be_empty
    end

    it 'accepts an assigned responsible user in the organization' do
      organization = create(:organization)
      responsible = create(:user)
      create(:organization_membership, organization:, user: responsible)
      supplier = described_class.new(organization:, responsible_user: responsible)
      supplier.send(:responsible_user_in_organization)
      expect(supplier.errors[:responsible_user]).to be_empty
    end

    it 'normalizes empty and padded email addresses' do
      supplier = described_class.new(email: '  USER@EXAMPLE.COM ')
      supplier.send(:normalize_email)
      expect(supplier.email).to eq('user@example.com')
      supplier.email = nil
      supplier.send(:normalize_email)
      expect(supplier.email).to be_nil
    end

    it 'does not normalize missing telephone values' do
      supplier = described_class.new
      supplier.send(:normalize_phone)
      expect(supplier.phone).to be_nil
    end
  end

  describe Purchases::ProcessReturn do
    it 'routes quarantined merchandise to the damaged-stock handler' do
      entry = double(stock_quarantined?: true)
      allow(described_class).to receive(:validate_available_return!)
      allow(described_class).to receive(:return_quarantined!)
      described_class.return_line!(entry, user: double)
      expect(described_class).to have_received(:return_quarantined!).with(entry)
    end

    it 'routes accepted merchandise to the available-stock handler' do
      entry = double(stock_quarantined?: false)
      user = double
      allow(described_class).to receive(:validate_available_return!)
      allow(described_class).to receive(:return_accepted!)
      described_class.return_line!(entry, user:)
      expect(described_class).to have_received(:return_accepted!).with(entry, user:)
    end
  end
end
