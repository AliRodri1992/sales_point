# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Purchasing flow negative-path behavior', type: :service do
  describe Purchases::ReceiveLine do
    let(:order) { double(outstanding_quantity_for: 5.to_d) }
    let(:line) { double('purchase line') }

    it 'rejects a negative delivered, accepted or damaged quantity' do
      %i[delivered accepted damaged].each do |key|
        values = { delivered: 3.to_d, accepted: 2.to_d, damaged: 1.to_d }
        values[key] = -1.to_d
        expect { described_class.validate_quantities!(order:, line:, **values) }
          .to raise_error(ArgumentError, /Invalid receiving quantities/)
      end
    end

    it 'rejects excess accepted plus damaged quantities' do
      expect do
        described_class.validate_quantities!(order:, line:, delivered: 2.to_d,
                                             accepted: 2.to_d, damaged: 1.to_d)
      end.to raise_error(ArgumentError, /exceed delivery/)
    end

    it 'rejects a zero delivery' do
      expect do
        described_class.validate_quantities!(order:, line:, delivered: 0.to_d,
                                             accepted: 0.to_d, damaged: 0.to_d)
      end.to raise_error(ArgumentError, /must be positive/)
    end

    it 'rejects over-receiving' do
      expect do
        described_class.validate_quantities!(order:, line:, delivered: 8.to_d,
                                             accepted: 8.to_d, damaged: 0.to_d)
      end.to raise_error(ArgumentError, /over-receive/)
    end

    it 'accepts a zero-damaged partial delivery' do
      expect do
        described_class.validate_quantities!(order:, line:, delivered: 3.to_d,
                                             accepted: 2.to_d, damaged: 0.to_d)
      end.not_to raise_error
    end
  end

  describe Purchases::BuildOrderFromQuotation do
    it 'rejects a rejected quotation, an expired quotation and an unaccepted quotation' do
      [
        double(accepted?: false, valid_until: nil),
        double(accepted?: true, valid_until: Date.yesterday),
        double(accepted?: false, valid_until: Date.tomorrow)
      ].each do |quotation|
        expect { described_class.validate_quotation!(quotation) }
          .to raise_error(ArgumentError, /accepted, unexpired/)
      end
    end

    it 'accepts an undated or future-dated accepted quotation' do
      [nil, Date.tomorrow].each do |date|
        expect { described_class.validate_quotation!(double(accepted?: true, valid_until: date)) }
          .not_to raise_error
      end
    end
  end

  describe Purchases::BuildQuotationFromRequest do
    it 'rejects an unapproved purchase request' do
      expect { described_class.call(request: double(approved?: false)) }
        .to raise_error(ArgumentError, /must be approved/)
    end

    it 'builds an empty draft quotation for an approved request without items' do
      request = PurchaseRequest.new
      allow(request).to receive(:approved?).and_return(true)
      quotation = described_class.call(request:)
      expect(quotation).to be_a(PurchaseQuotation)
      expect(quotation.purchase_quotation_items).to be_empty
    end
  end

  describe Inventories::ApplyMovement do
    it 'rejects zero quantities and invalid kinds' do
      inventory = double('Inventory')
      expect { described_class.validate_movement!(inventory:, amount: 0.to_d, kind: 'purchase', lot: nil) }
        .to raise_error(ArgumentError, /must not be zero/)
      expect { described_class.validate_movement!(inventory:, amount: 1.to_d, kind: 'unsupported', lot: nil) }
        .to raise_error(ArgumentError, /Invalid movement kind/)
    end

    it 'requires correct lot association for tracked inventory' do
      inventory = double(id: 1, product: double(tracking_none?: false))
      expect { described_class.validate_tracking!(inventory:, lot: nil) }
        .to raise_error(ArgumentError, /requires a lot-specific/)
      expect { described_class.validate_tracking!(inventory:, lot: double(inventory_id: 9)) }
        .to raise_error(ArgumentError, /another inventory/)
      expect { described_class.validate_tracking!(inventory:, lot: double(inventory_id: 1)) }
        .not_to raise_error
    end

    it 'allows nontracked inventory without any lot' do
      inventory = double(id: 1, product: double(tracking_none?: true))
      expect { described_class.validate_tracking!(inventory:, lot: nil) }.not_to raise_error
    end
  end

  describe Onboarding::Requirement do
    let(:organization) { double('Organization') }

    it 'treats an unconfigured section as complete' do
      allow(Onboarding::ProgressCalculator).to receive(:call).and_return(sections: [])
      expect(described_class.call(organization:, section: :unknown)).to include(complete: true, percentage: 100)
    end

    it 'reports partial and completed section percentages' do
      [40, 100].each do |percent|
        allow(Onboarding::ProgressCalculator).to receive(:call)
          .and_return(sections: [{ key: :branch, percentage: percent }])
        result = described_class.call(organization:, section: :branch)
        expect(result[:complete]).to eq(percent == 100)
        expect(result[:percentage]).to eq(percent)
      end
    end
  end
end
