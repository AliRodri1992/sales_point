# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accounts payable allocation guard paths', type: :service do
  describe AccountsPayable::ApplyCredit do
    let(:invoice) { double(posted?: true, currency_id: 3) }
    let(:credit) do
      double(posted?: true, organization_id: 1, supplier_id: 2,
             currency_id: 3, available_amount: 100.to_d)
    end
    let(:payable) do
      double(supplier_invoice: invoice, organization_id: 1,
             supplier_id: 2, balance: 100.to_d)
    end

    def allocation(amount = '30')
      described_class.new(credit_note: credit, account_payable: payable, amount:, actor: nil)
    end

    it 'permits valid allocations within supplier, currency and balance limits' do
      expect { allocation.send(:validate_allocation!) }.not_to raise_error
    end

    it 'rejects credit notes not yet posted' do
      allow(credit).to receive(:posted?).and_return(false)
      expect { allocation.send(:validate_allocation!) }.to raise_error(ArgumentError, /Credit must be posted/)
    end

    it 'rejects invoices that were not posted' do
      allow(invoice).to receive(:posted?).and_return(false)
      expect { allocation.send(:validate_allocation!) }.to raise_error(ArgumentError, /Invoice must be posted/)
    end

    it 'rejects a credit belonging to another organization' do
      allow(credit).to receive(:organization_id).and_return(99)
      expect { allocation.send(:validate_allocation!) }
        .to raise_error(ArgumentError, /Different organization or supplier/)
    end

    it 'rejects a credit from another supplier' do
      allow(credit).to receive(:supplier_id).and_return(99)
      expect { allocation.send(:validate_allocation!) }
        .to raise_error(ArgumentError, /Different organization or supplier/)
    end

    it 'rejects credit in a different currency' do
      allow(credit).to receive(:currency_id).and_return(99)
      expect { allocation.send(:validate_allocation!) }.to raise_error(ArgumentError, /Different currency/)
    end

    it 'rejects zero and negative credit amounts' do
      ['0', '-1'].each do |amount|
        expect { allocation(amount).send(:validate_allocation!) }
          .to raise_error(ArgumentError, /Invalid credit amount/)
      end
    end

    it 'rejects allocations greater than available credit' do
      allow(credit).to receive(:available_amount).and_return(10.to_d)
      expect { allocation.send(:validate_allocation!) }
        .to raise_error(ArgumentError, /Insufficient available credit/)
    end

    it 'rejects allocations greater than the outstanding invoice balance' do
      allow(payable).to receive(:balance).and_return(10.to_d)
      expect { allocation.send(:validate_allocation!) }
        .to raise_error(ArgumentError, /Credit exceeds open balance/)
    end
  end

  describe AccountsPayable::ApplyPayment do
    def posting(entries, total = 100.to_d)
      described_class.new(payment: double(amount: total), allocations: entries, actor: nil)
    end

    it 'rejects empty payment allocations' do
      expect { posting([]).send(:parsed_entries) }
        .to raise_error(ArgumentError, /cannot be empty/)
    end

    it 'rejects duplicate allocations to the same payable' do
      entries = [{ account_payable_id: 1, amount: '50' }, { account_payable_id: 1, amount: '50' }]
      expect { posting(entries).send(:parsed_entries) }
        .to raise_error(ArgumentError, /Duplicate payable/)
    end

    it 'rejects payment amounts that do not match allocations' do
      entries = [{ account_payable_id: 1, amount: '20' }]
      expect { posting(entries).send(:parsed_entries) }
        .to raise_error(ArgumentError, /Payment amount differs/)
    end

    it 'accepts amounts allocated exactly across multiple payables' do
      entries = [{ account_payable_id: 1, amount: '40' }, { account_payable_id: 2, amount: '60' }]
      expect(posting(entries).send(:parsed_entries).sum(&:last)).to eq(100.to_d)
    end
  end
end
