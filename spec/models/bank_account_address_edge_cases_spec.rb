# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bank account, supplier and address validation branches', type: :model do
  describe SupplierBankAccount do
    it 'only validates populated account numbers' do
      record = described_class.new
      allow(record).to receive(:account_number).and_return(nil)
      record.send(:valid_account_number)
      expect(record.errors[:account_number]).to be_empty

      allow(record).to receive(:account_number).and_return('not-numeric')
      record.send(:valid_account_number)
      expect(record.errors[:account_number]).not_to be_empty
    end

    it 'accepts account numbers with four to twenty digits' do
      record = described_class.new
      allow(record).to receive(:account_number).and_return('1234567890')
      record.send(:valid_account_number)
      expect(record.errors[:account_number]).to be_empty
    end

    it 'rejects invalid CLABE formats and invalid check digits' do
      record = described_class.new
      allow(record).to receive(:clabe).and_return('123')
      record.send(:valid_clabe)
      expect(record.errors[:clabe]).not_to be_empty
      record.errors.clear
      allow(record).to receive(:clabe).and_return('111111111111111111')
      record.send(:valid_clabe)
      expect(record.errors[:clabe]).not_to be_empty
    end

    it 'accepts CLABE with a correctly computed checksum' do
      record = described_class.new
      allow(record).to receive(:clabe).and_return('000000000000000000')
      record.send(:valid_clabe)
      expect(record.errors[:clabe]).to be_empty
    end

    it 'compares SAT bank prefix only when both fields exist' do
      record = described_class.new(sat_bank_code: '002')
      allow(record).to receive(:clabe).and_return(nil)
      record.send(:consistent_bank_code)
      expect(record.errors[:sat_bank_code]).to be_empty

      allow(record).to receive(:clabe).and_return('999000000000000000')
      record.send(:consistent_bank_code)
      expect(record.errors[:sat_bank_code]).not_to be_empty
      record.errors.clear

      allow(record).to receive(:clabe).and_return('002000000000000000')
      record.send(:consistent_bank_code)
      expect(record.errors[:sat_bank_code]).to be_empty
    end

    it 'rejects accounts linked to another supplier organization' do
      record = described_class.new(organization_id: 1)
      allow(record).to receive(:supplier).and_return(double(organization_id: 2))
      record.send(:same_organization)
      expect(record.errors[:supplier]).not_to be_empty

      record.errors.clear
      allow(record).to receive(:supplier).and_return(double(organization_id: 1))
      record.send(:same_organization)
      expect(record.errors[:supplier]).to be_empty
    end

    it 'formats missing and present masked account values' do
      record = described_class.new
      allow(record).to receive(:last_four).and_return(nil)
      expect(record.masked_number).to eq('••••')
      allow(record).to receive(:last_four).and_return('0123')
      expect(record.masked_number).to include('0123')
    end
  end

  describe SupplierPayment do
    it 'rejects another organization supplier' do
      payment = described_class.new(organization_id: 1)
      allow(payment).to receive(:supplier).and_return(double(organization_id: 2))
      payment.send(:matching_organization)
      expect(payment.errors[:supplier]).not_to be_empty
    end

    it 'skips bank validation when bank reference is absent' do
      payment = described_class.new(organization_id: 1)
      payment.send(:matching_organization)
      expect(payment.errors[:supplier_bank_account]).to be_empty
    end

    it 'rejects invalid bank account references' do
      payment = described_class.new(organization_id: 1, supplier_id: 2, supplier_bank_account_id: 3)
      allow(payment).to receive(:currency).and_return(double(code: 'MXN'))
      allow(SupplierBankAccount).to receive(:active).and_return(double(exists?: false))
      payment.send(:matching_organization)
      expect(payment.errors[:supplier_bank_account]).not_to be_empty
    end

    it 'accepts authorized bank account references' do
      payment = described_class.new(organization_id: 1, supplier_id: 2, supplier_bank_account_id: 3)
      allow(payment).to receive(:currency).and_return(double(code: 'MXN'))
      allow(SupplierBankAccount).to receive(:active).and_return(double(exists?: true))
      payment.send(:matching_organization)
      expect(payment.errors[:supplier_bank_account]).to be_empty
    end
  end

  describe Address do
    it 'does not restore an address that has not been deleted' do
      expect(described_class.new.restore_safely).to be(false)
    end

    it 'restores a deleted address after a successful save' do
      address = described_class.new(deleted_at: 1.day.ago)
      allow(address).to receive(:save).and_return(true)
      expect(address.restore_safely).to be(true)
      expect(address.deleted_at).to be_nil
    end

    it 'restores deletion timestamp after failed save' do
      deleted_at = 1.day.ago
      address = described_class.new(deleted_at:)
      allow(address).to receive(:save).and_return(false)
      expect(address.restore_safely).to be(false)
      expect(address.deleted_at).to be_within(1.second).of(deleted_at)
    end

    it 'rejects two active primary addresses for the same owner' do
      address = described_class.new(primary: true)
      allow(address).to receive(:addressable).and_return(double(persisted?: true))
      allow(address).to receive(:other_primary_address_exists?).and_return(true)
      address.single_primary_address
      expect(address.errors[:primary]).not_to be_empty
    end

    it 'allows a non-primary address without checking other primary addresses' do
      address = described_class.new(primary: false)
      expect(address).not_to receive(:other_primary_address_exists?)
      address.single_primary_address
      expect(address.errors[:primary]).to be_empty
    end
  end

  describe Currency do
    it 'normalizes codes and leaves absent codes unchanged' do
      currency = described_class.new(code: ' mxn ')
      currency.send(:normalize_code)
      expect(currency.code).to eq('MXN')
      currency.code = nil
      currency.send(:normalize_code)
      expect(currency.code).to be_nil
    end
  end
end
