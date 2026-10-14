# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Finance, inventory and costing service decision branches' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:actor) { create(:user) }
  let(:currency) { supplier.currency }

  def invoice(status: :posted, supplier_record: supplier, currency_record: currency)
    SupplierInvoice.new(
      organization:, supplier: supplier_record, currency: currency_record,
      created_by: actor, status:, total: 20, subtotal: 20,
      issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow
    )
  end

  def payable(status: :posted, amount: 20, supplier_record: supplier, currency_record: currency)
    AccountPayable.new(
      organization:, supplier: supplier_record,
      supplier_invoice: invoice(status:, supplier_record:, currency_record:),
      amount:, due_on: Date.tomorrow
    )
  end

  def payment(status: :draft, amount: 20)
    SupplierPayment.new(
      organization:, supplier:, currency:, created_by: actor,
      status:, amount:, paid_on: Date.current
    )
  end

  def payment_service(allocations, current_payment: payment)
    AccountsPayable::ApplyPayment.new(payment: current_payment, allocations:, actor:)
  end

  it 'rejects posting a payment more than once' do
    expect { payment_service([], current_payment: payment(status: :posted)).send(:verify_draft!) }
      .to raise_error(ArgumentError, /already processed/)
  end

  it 'rejects empty payment allocations' do
    expect { payment_service([]).send(:parsed_entries) }
      .to raise_error(ArgumentError, /cannot be empty/)
  end

  it 'rejects duplicate payment allocation targets' do
    entries = [{ account_payable_id: 1, amount: 10 }, { account_payable_id: 1, amount: 10 }]
    expect { payment_service(entries).send(:parsed_entries) }
      .to raise_error(ArgumentError, /Duplicate payable/)
  end

  it 'rejects payments whose distribution is different from the amount' do
    entries = [{ account_payable_id: 1, amount: 10 }]
    expect { payment_service(entries).send(:parsed_entries) }
      .to raise_error(ArgumentError, /differs/)
  end

  it 'allows distinct payment allocations whose sum matches the payment' do
    entries = [{ account_payable_id: 1, amount: '7' }, { account_payable_id: 2, amount: '13' }]
    expect(payment_service(entries).send(:parsed_entries)).to eq([[1, 7.to_d], [2, 13.to_d]])
  end

  it 'rejects an allocation amount that is zero' do
    expect { payment_service([]).send(:allocate!, payable, 0.to_d) }
      .to raise_error(ArgumentError, /Invalid payment amount/)
  end

  it 'rejects payment allocation for a different supplier' do
    other_supplier = create(:supplier, organization:)
    debt = payable(supplier_record: other_supplier)
    expect { payment_service([]).send(:allocate!, debt, 5.to_d) }
      .to raise_error(ArgumentError, /Different supplier or currency/)
  end

  it 'rejects payment allocation for a different currency' do
    foreign_currency = create(:currency)
    debt = payable(currency_record: foreign_currency)
    expect { payment_service([]).send(:allocate!, debt, 5.to_d) }
      .to raise_error(ArgumentError, /Different supplier or currency/)
  end

  it 'rejects payment allocation for a draft invoice' do
    expect { payment_service([]).send(:allocate!, payable(status: :draft), 5.to_d) }
      .to raise_error(ArgumentError, /Invoice not posted/)
  end

  it 'rejects payment allocation exceeding the remaining balance' do
    expect { payment_service([]).send(:allocate!, payable, 30.to_d) }
      .to raise_error(ArgumentError, /exceeds open balance/)
  end

  def credit(status: :posted, total: 20, supplier_record: supplier, currency_record: currency)
    SupplierCreditNote.new(
      organization:, supplier: supplier_record, currency: currency_record,
      created_by: actor, status:, total:, issued_on: Date.current
    )
  end

  def credit_service(current_credit: credit, debt: payable, amount: 5)
    AccountsPayable::ApplyCredit.new(
      credit_note: current_credit, account_payable: debt, amount:, actor:
    )
  end

  it 'rejects allocating draft credits' do
    expect { credit_service(current_credit: credit(status: :draft)).send(:validate_allocation!) }
      .to raise_error(ArgumentError, /must be posted/)
  end

  it 'rejects allocating credit against draft invoices' do
    expect { credit_service(debt: payable(status: :draft)).send(:validate_allocation!) }
      .to raise_error(ArgumentError, /Invoice must be posted/)
  end

  it 'rejects allocating a credit from another supplier' do
    other_supplier = create(:supplier, organization:)
    expect { credit_service(current_credit: credit(supplier_record: other_supplier)).send(:validate_allocation!) }
      .to raise_error(ArgumentError, /Different organization or supplier/)
  end

  it 'rejects allocating credits in another currency' do
    other_currency = create(:currency)
    expect { credit_service(current_credit: credit(currency_record: other_currency)).send(:validate_allocation!) }
      .to raise_error(ArgumentError, /Different currency/)
  end

  it 'rejects a zero-value credit allocation' do
    expect { credit_service(amount: 0).send(:validate_allocation!) }
      .to raise_error(ArgumentError, /Invalid credit amount/)
  end

  it 'rejects credit allocations larger than the remaining credit' do
    expect { credit_service(current_credit: credit(total: 10), amount: 15).send(:validate_allocation!) }
      .to raise_error(ArgumentError, /Insufficient available credit/)
  end

  it 'rejects credit allocations larger than the remaining debt' do
    expect { credit_service(debt: payable(amount: 7), amount: 10).send(:validate_allocation!) }
      .to raise_error(ArgumentError, /exceeds open balance/)
  end

  it 'accepts feasible credit allocations before writing the database entry' do
    expect { credit_service.send(:validate_allocation!) }.not_to raise_error
  end

  it 'handles zero received quantities when calculating landed cost' do
    entry = double(accepted_quantity: 0)
    expect(Purchases::Costing.landed_cost(entry:, goods: 10, exchange_rate: 1, freight: 0, insurance: 0))
      .to eq(0)
  end

  it 'rejects receipt expenses that yield negative landed value' do
    entry = double(accepted_quantity: 1)
    expect do
      Purchases::Costing.landed_cost(
        entry:, goods: 10, exchange_rate: 1, freight: 0, insurance: 0, additional_discount: 30
      )
    end.to raise_error(ArgumentError, /discount exceeds/)
  end

  it 'calculates converted landed cost including expenses' do
    entry = double(accepted_quantity: 2)
    value = Purchases::Costing.landed_cost(
      entry:, goods: 20, exchange_rate: 2, freight: 2, insurance: 2, extra_expenses: 1
    )
    expect(value).to eq(25)
  end

  it 'allocates estimated freight when actual freight is missing' do
    expect(Purchases::Costing.cost_share(nil, 100, 0.2, 0.4)).to eq(40)
  end

  it 'allocates actual freight by receipt weight' do
    expect(Purchases::Costing.cost_share(100, 200, 0.2, 0.4)).to eq(20)
  end

  it 'disallows sales from expired FEFO lots' do
    lot = double(expires_on: Date.yesterday)
    expect(Inventories::FefoAllocator.expiration_allowed?(lot, 'sale')).to be(false)
  end

  it 'permits FEFO returns for expired lots' do
    lot = double(expires_on: Date.yesterday)
    expect(Inventories::FefoAllocator.expiration_allowed?(lot, 'return')).to be(true)
  end

  it 'permits lot consumption when no expiration date exists' do
    lot = double(expires_on: nil)
    expect(Inventories::FefoAllocator.expiration_allowed?(lot, 'sale')).to be(true)
  end

  it 'permits lot consumption until its expiration date' do
    lot = double(expires_on: Date.current)
    expect(Inventories::FefoAllocator.expiration_allowed?(lot, 'sale')).to be(true)
  end

  def eligible_lot?(**overrides)
    options = {
      quantity: 2, lot_quantity: 5, inventory_stock: 10,
      inventory_id: 3, lot_inventory_id: 3, active: true, expires_on: nil
    }.merge(overrides)
    inventory = double(id: options[:inventory_id], stock: options[:inventory_stock])
    lot = double(inventory_id: options[:lot_inventory_id], available?: options[:active],
                 quantity: options[:lot_quantity], expires_on: options[:expires_on])
    Inventories::FefoAllocator.lot_eligible?(
      inventory:, lot:, quantity: options[:quantity].to_d, kind: 'sale'
    )
  end

  it 'accepts an eligible unexpired FEFO lot' do
    expect(check_lot).to be(true)
  end

  it 'rejects FEFO lot with a zero requested quantity' do
    expect(eligible_lot?(quantity: 0)).to be(false)
  end

  it 'rejects a FEFO lot belonging to another inventory' do
    expect(eligible_lot?(lot_inventory_id: 9)).to be(false)
  end

  it 'rejects a FEFO lot that is unavailable' do
    expect(eligible_lot?(active: false)).to be(false)
  end

  it 'rejects a FEFO lot with insufficient quantity' do
    expect(eligible_lot?(lot_quantity: 1)).to be(false)
  end

  it 'rejects a FEFO lot when total inventory stock is insufficient' do
    expect(eligible_lot?(inventory_stock: 1)).to be(false)
  end

  it 'rejects a FEFO lot that expired before today' do
    expect(eligible_lot?(expires_on: Date.yesterday)).to be(false)
  end
end
