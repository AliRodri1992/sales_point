require 'rails_helper'

RSpec.describe SatTax, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:sat_tax)).to be_valid
    end
  end

  describe 'validations' do
    subject { build(:sat_tax) }

    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:name) }

    it { should validate_inclusion_of(:tax_type).in_array(SatTax::TAX_TYPES) }
    it { should validate_inclusion_of(:factor_type).in_array(SatTax::FACTOR_TYPES) }

    it do
      should validate_inclusion_of(:applies_to)
        .in_array(SatTax::APPLIES_TO)
        .allow_nil
    end

    it { should validate_numericality_of(:priority).is_greater_than_or_equal_to(0) }
  end

  describe 'custom validations' do
    let(:sat_tax) { build(:sat_tax) }

    describe '#valid_date_range' do
      it 'is invalid when valid_to < valid_from' do
        sat_tax.valid_from = Time.zone.today
        sat_tax.valid_to = Date.yesterday

        expect(sat_tax).not_to be_valid
        expect(sat_tax.errors[:valid_to]).to include('must be greater than or equal to valid_from')
      end

      it 'is valid when dates are correct' do
        sat_tax.valid_from = Time.zone.today
        sat_tax.valid_to = Date.tomorrow

        expect(sat_tax).to be_valid
      end

      it 'is valid when valid_to is nil' do
        sat_tax.valid_from = Time.zone.today
        sat_tax.valid_to = nil

        expect(sat_tax).to be_valid
      end
    end

    describe '#tax_logic_consistency' do
      it 'requires transferable for transfer taxes' do
        sat_tax.tax_type = 'transfer'
        sat_tax.is_transferrable = false

        expect(sat_tax).not_to be_valid
        expect(sat_tax.errors[:is_transferrable])
          .to include('must be TRUE for transfer taxes')
      end

      it 'requires retainable for withheld taxes' do
        sat_tax.tax_type = 'withheld'
        sat_tax.is_retainable = false

        expect(sat_tax).not_to be_valid
        expect(sat_tax.errors[:is_retainable])
          .to include('must be TRUE for withheld taxes')
      end
    end
  end

  describe 'callbacks' do
    it 'normalizes fields before validation' do
      sat_tax = build(:sat_tax,
                      code: ' abc ',
                      name: ' iva ',
                      applies_to: ' PRODUCT ')

      sat_tax.valid?

      expect(sat_tax.code).to eq('ABC')
      expect(sat_tax.name).to eq('iva')
      expect(sat_tax.applies_to).to eq('product')
    end

    it 'handles nil applies_to safely' do
      sat_tax = build(:sat_tax, applies_to: nil)

      expect { sat_tax.valid? }.not_to raise_error
    end
  end

  describe 'scopes' do
    let!(:active_tax) { create(:sat_tax, :active) }
    let!(:inactive_tax) { create(:sat_tax, status: false) }
    let!(:deleted_tax) { create(:sat_tax, deleted_at: Time.current) }

    describe '.active' do
      it 'returns only active and not deleted records' do
        expect(SatTax.active).to include(active_tax)
        expect(SatTax.active).not_to include(inactive_tax)
        expect(SatTax.active).not_to include(deleted_tax)
      end
    end

    describe '.by_type' do
      it 'filters by tax_type' do
        transfer = create(:sat_tax, :transfer)
        withheld = create(:sat_tax, :withheld)

        expect(SatTax.by_type('transfer')).to include(transfer)
        expect(SatTax.by_type('transfer')).not_to include(withheld)
      end
    end

    describe '.valid_on' do
      it 'returns taxes valid for given date' do
        tax = create(:sat_tax,
                     valid_from: Date.yesterday,
                     valid_to: Date.tomorrow)

        expect(SatTax.valid_on(Time.zone.today)).to include(tax)
      end

      it 'excludes taxes outside range' do
        tax = create(:sat_tax,
                     valid_from: 10.days.ago,
                     valid_to: 5.days.ago)

        expect(SatTax.valid_on(Time.zone.today)).not_to include(tax)
      end
    end

    describe '.for_products / .for_services' do
      let!(:product_tax) { create(:sat_tax, applies_to: 'product') }
      let!(:service_tax) { create(:sat_tax, applies_to: 'service') }
      let!(:both_tax) { create(:sat_tax, applies_to: 'both') }

      it 'returns correct product taxes' do
        expect(SatTax.for_products).to include(product_tax, both_tax)
        expect(SatTax.for_products).not_to include(service_tax)
      end

      it 'returns correct service taxes' do
        expect(SatTax.for_services).to include(service_tax, both_tax)
        expect(SatTax.for_services).not_to include(product_tax)
      end
    end
  end

  describe 'instance methods' do
    let(:tax) { build(:sat_tax) }

    it 'detects transfer type' do
      tax.tax_type = 'transfer'
      expect(tax.transfer?).to be true
    end

    it 'detects withheld type' do
      tax.tax_type = 'withheld'
      expect(tax.withheld?).to be true
    end

    it 'detects factor types correctly' do
      tax.factor_type = 'rate'
      expect(tax.rate?).to be true

      tax.factor_type = 'quota'
      expect(tax.quota?).to be true

      tax.factor_type = 'exempt'
      expect(tax.exempt?).to be true
    end

    it 'checks active state' do
      tax.status = true
      tax.deleted_at = nil

      expect(tax.active?).to be true
    end

    it 'validates date range logic' do
      tax.valid_from = Date.yesterday
      tax.valid_to = Date.tomorrow

      expect(tax.valid_for_date?(Time.zone.today)).to be true
    end
  end
end
