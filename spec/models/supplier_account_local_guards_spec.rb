# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier account local validation edge paths', type: :model do
  describe SupplierBankAccount do
    let(:account) { described_class.new }

    it 'skips absent CLABE validation' do
      allow(account).to receive(:clabe).and_return(nil)
      account.send(:valid_clabe)
      expect(account.errors[:clabe]).to be_empty
    end

    it 'skips absent account number validation' do
      allow(account).to receive(:account_number).and_return(nil)
      account.send(:valid_account_number)
      expect(account.errors[:account_number]).to be_empty
    end

    it 'requires a nonempty CLABE before validating bank prefix' do
      allow(account).to receive(:clabe).and_return(nil)
      allow(account).to receive(:sat_bank_code).and_return('002')
      account.send(:consistent_bank_code)
      expect(account.errors[:sat_bank_code]).to be_empty
    end

    it 'allows missing bank codes when a CLABE was entered' do
      allow(account).to receive(:clabe).and_return('002000000000000000')
      allow(account).to receive(:sat_bank_code).and_return(nil)
      account.send(:consistent_bank_code)
      expect(account.errors[:sat_bank_code]).to be_empty
    end

    it 'normalizes bank codes and account fragments' do
      expect(account.send(:compact_number, " 12 34\n")).to eq('1234')
      expect(account.send(:compact_number, nil)).to be_nil
    end
  end

  describe CountryCurrency do
    it 'skips uniqueness checking before a country has been assigned' do
      record = described_class.new(is_primary: true, country_id: nil)
      record.send(:only_one_primary_currency)
      expect(record.errors[:is_primary]).to be_empty
    end
  end
end
