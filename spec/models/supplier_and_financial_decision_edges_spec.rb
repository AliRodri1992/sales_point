# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier validation and financial reversal decision branches', type: :model do
  describe Supplier do
    it 'rejects an RFC with invalid calendar date' do
      supplier = described_class.new(person_type: 'individual', rfc: 'ABCD260230XYZ')
      supplier.send(:rfc_must_match_person_type_and_date)
      expect(supplier.errors[:rfc]).not_to be_empty
    end

    it 'accepts a valid calendar date in an individual RFC' do
      supplier = described_class.new(person_type: 'individual', rfc: 'ABCD260228XYZ')
      supplier.send(:rfc_must_match_person_type_and_date)
      expect(supplier.errors[:rfc]).to be_empty
    end

    it 'rejects an RFC whose length mismatches person type' do
      supplier = described_class.new(person_type: 'company', rfc: 'ABCD260228XYZ')
      supplier.send(:rfc_must_match_person_type_and_date)
      expect(supplier.errors[:rfc]).not_to be_empty
    end

    it 'does not attempt date validation for malformed RFCs' do
      supplier = described_class.new(person_type: 'company', rfc: 'invalid')
      expect(supplier).not_to receive(:rfc_date_valid?)
      supplier.send(:rfc_must_match_person_type_and_date)
      expect(supplier.errors[:rfc]).to be_empty
    end

    it 'normalizes a tag list and removes duplicates and blanks' do
      supplier = described_class.new
      supplier.tags_text = 'food, food, , drinks'
      expect(supplier.tags).to eq(%w[food drinks])
    end

    it 'skips missing phone numbers and rejects invalid phone numbers' do
      supplier = described_class.new
      supplier.send(:phone_must_be_valid)
      expect(supplier.errors[:phone]).to be_empty
      supplier.phone = '123'
      supplier.send(:phone_must_be_valid)
      expect(supplier.errors[:phone]).not_to be_empty
    end
  end

  describe AccountsPayable::CancelInvoice do
    it 'recognizes invoices without any payable as free of financial movements' do
      invoice = double(account_payable: nil)
      expect(described_class.financial_movements?(invoice)).to be(false)
    end

    it 'recognizes invoices with posted payment allocations' do
      payable = double(supplier_payment_allocations: double(exists?: true))
      invoice = double(account_payable: payable)
      expect(described_class.financial_movements?(invoice)).to be(true)
    end

    it 'recognizes notes of credit even when no payment exists' do
      payable = double(supplier_payment_allocations: double(exists?: false),
                       supplier_credit_allocations: double(exists?: true))
      invoice = double(account_payable: payable)
      expect(described_class.financial_movements?(invoice)).to be(true)
    end

    it 'allows cancellation checks when neither payment nor credit exists' do
      payable = double(supplier_payment_allocations: double(exists?: false),
                       supplier_credit_allocations: double(exists?: false))
      invoice = double(account_payable: payable)
      expect(described_class.financial_movements?(invoice)).to be(false)
    end
  end
end
