# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Supplier return quantity and disposition constraints' do
  let(:service) { Purchases::ProcessReturn }
  let(:receipt_item) { double(accepted_quantity: 4.to_d, damaged_quantity: 3.to_d) }

  def return_entry(quantity:, quarantined:)
    double(
      quantity: quantity.to_d, goods_receipt_item: receipt_item,
      stock_disposition: quarantined ? 'quarantined' : 'accepted',
      stock_quarantined?: quarantined
    )
  end

  def past_returns(value)
    relation = double('prior returns')
    allow(PurchaseReturnItem).to receive(:joins).with(:purchase_return).and_return(relation)
    allow(relation).to receive(:where).and_return(relation)
    allow(relation).to receive(:sum).with(:quantity).and_return(value.to_d)
  end

  it 'allows an accepted return below the delivered limit' do
    past_returns(0)
    expect { service.validate_available_return!(return_entry(quantity: 2, quarantined: false)) }
      .not_to raise_error
  end

  it 'allows an accepted return exactly up to its limit' do
    past_returns(2)
    expect { service.validate_available_return!(return_entry(quantity: 2, quarantined: false)) }
      .not_to raise_error
  end

  it 'rejects an accepted return that exceeds the delivery amount' do
    past_returns(3)
    expect { service.validate_available_return!(return_entry(quantity: 2, quarantined: false)) }
      .to raise_error(ArgumentError, /accepted merchandise/)
  end

  it 'accepts quarantined merchandise up to the damaged quantity' do
    past_returns(1)
    expect { service.validate_available_return!(return_entry(quantity: 2, quarantined: true)) }
      .not_to raise_error
  end

  it 'rejects damaged returns larger than quarantined inventory' do
    past_returns(2)
    expect { service.validate_available_return!(return_entry(quantity: 2, quarantined: true)) }
      .to raise_error(ArgumentError, /damaged merchandise/)
  end

  it 'routes an accepted stock return into lot consumption' do
    entry = return_entry(quantity: 1, quarantined: false)
    allow(service).to receive(:validate_available_return!)
    allow(service).to receive(:return_accepted!)
    service.return_line!(entry, user: nil)
    expect(service).to have_received(:return_accepted!).with(entry, user: nil)
  end

  it 'routes damaged stock return into quarantined lot handling' do
    entry = return_entry(quantity: 1, quarantined: true)
    allow(service).to receive(:validate_available_return!)
    allow(service).to receive(:return_quarantined!)
    service.return_line!(entry, user: nil)
    expect(service).to have_received(:return_quarantined!).with(entry)
  end
end
