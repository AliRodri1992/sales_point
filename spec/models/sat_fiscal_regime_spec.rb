require 'rails_helper'

RSpec.describe SatFiscalRegime, type: :model do
  subject(:regime) { build(:sat_fiscal_regime) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(regime).to be_valid
    end

    it 'is invalid without code' do
      regime.code = nil
      expect(regime).not_to be_valid
    end

    it 'is invalid if code length is not 3' do
      regime.code = '12'
      expect(regime).not_to be_valid
    end

    it 'is invalid without description' do
      regime.description = nil
      expect(regime).not_to be_valid
    end

    it 'is invalid with invalid person_type' do
      regime.person_type = 'X'
      expect(regime).not_to be_valid
    end

    it 'is invalid if valid_to < valid_from' do
      regime.valid_from = Time.zone.today
      regime.valid_to = Date.yesterday
      expect(regime).not_to be_valid
    end

    it 'validates uniqueness of code scoped to deleted_at' do
      create(:sat_fiscal_regime, code: '601')

      duplicate = build(:sat_fiscal_regime, code: '601')
      expect(duplicate).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_regime) { create(:sat_fiscal_regime, deleted_at: nil) }
    let!(:deleted_regime) { create(:sat_fiscal_regime, deleted_at: Time.current) }

    describe '.active' do
      it 'returns only non-deleted records' do
        expect(SatFiscalRegime.active).to include(active_regime)
        expect(SatFiscalRegime.active).not_to include(deleted_regime)
      end
    end

    describe '.for_person' do
      let!(:physical) { create(:sat_fiscal_regime, person_type: 'F') }
      let!(:moral) { create(:sat_fiscal_regime, person_type: 'M') }

      it 'returns only physical persons' do
        expect(SatFiscalRegime.for_person('F')).to include(physical)
        expect(SatFiscalRegime.for_person('F')).not_to include(moral)
      end

      it 'returns none for invalid type' do
        expect(SatFiscalRegime.for_person('X')).to be_empty
      end
    end

    describe '.valid_on' do
      let!(:valid_regime) do
        create(:sat_fiscal_regime,
               valid_from: Date.yesterday,
               valid_to: Date.tomorrow)
      end

      let!(:invalid_regime) do
        create(:sat_fiscal_regime,
               valid_from: 10.days.ago,
               valid_to: 5.days.ago)
      end

      it 'returns only regimes valid for given date' do
        result = SatFiscalRegime.valid_on(Time.zone.today)

        expect(result).to include(valid_regime)
        expect(result).not_to include(invalid_regime)
      end
    end

    describe '.current' do
      it 'returns active and valid records' do
        regime = create(:sat_fiscal_regime,
                        valid_from: Date.yesterday,
                        valid_to: Date.tomorrow)

        expect(SatFiscalRegime.current).to include(regime)
      end
    end
  end

  describe '.for_cfdi' do
    let!(:regime) do
      create(:sat_fiscal_regime,
             code: '601',
             valid_from: Date.yesterday,
             valid_to: Date.tomorrow)
    end

    it 'returns valid regime by code and date' do
      result = SatFiscalRegime.for_cfdi('601', Time.zone.today)
      expect(result).to eq(regime)
    end

    it 'returns nil if not valid for date' do
      result = SatFiscalRegime.for_cfdi('601', 10.years.from_now)
      expect(result).to be_nil
    end
  end

  describe '.exists_for_cfdi?' do
    before do
      create(:sat_fiscal_regime,
             code: '601',
             valid_from: Date.yesterday,
             valid_to: Date.tomorrow)
    end

    it 'returns true if exists' do
      expect(SatFiscalRegime.exists_for_cfdi?('601')).to be true
    end

    it 'returns false if not exists' do
      expect(SatFiscalRegime.exists_for_cfdi?('999')).to be false
    end
  end

  describe 'instance methods' do
    describe '#physical_person?' do
      it 'returns true for F' do
        regime.person_type = 'F'
        expect(regime.physical_person?).to be true
      end
    end

    describe '#moral_person?' do
      it 'returns true for M' do
        regime.person_type = 'M'
        expect(regime.moral_person?).to be true
      end
    end

    describe '#active?' do
      it 'returns true if not deleted' do
        regime.deleted_at = nil
        expect(regime.active?).to be true
      end

      it 'returns false if deleted' do
        regime.deleted_at = Time.current
        expect(regime.active?).to be false
      end
    end

    describe '#valid_for_date?' do
      it 'returns true when date is within range' do
        regime.valid_from = Date.yesterday
        regime.valid_to = Date.tomorrow

        expect(regime.valid_for_date?(Time.zone.today)).to be true
      end

      it 'returns false when date is out of range' do
        regime.valid_from = 10.days.ago
        regime.valid_to = 5.days.ago

        expect(regime.valid_for_date?(Time.zone.today)).to be false
      end
    end
  end

  describe 'callbacks' do
    it 'normalizes fields before validation' do
      regime.code = ' 601 '
      regime.person_type = ' f '

      regime.valid?

      expect(regime.code).to eq('601')
      expect(regime.person_type).to eq('F')
    end
  end
end
