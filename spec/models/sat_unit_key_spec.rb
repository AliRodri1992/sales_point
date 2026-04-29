require 'rails_helper'

RSpec.describe SatUnitKey, type: :model do
  subject(:unit_key) { build(:sat_unit_key) }

  # =========================
  # VALIDATIONS
  # =========================
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(unit_key).to be_valid
    end

    it 'is invalid without code' do
      unit_key.code = nil
      expect(unit_key).not_to be_valid
    end

    it 'is invalid with lowercase code' do
      unit_key.code = 'abc'
      unit_key.validate
      expect(unit_key.code).to eq('ABC') # normalized
    end

    it 'is invalid with invalid format' do
      unit_key.code = 'abc-123'
      expect(unit_key).not_to be_valid
    end

    it 'is invalid without description' do
      unit_key.description = nil
      expect(unit_key).not_to be_valid
    end

    it 'validates uniqueness of code (case insensitive)' do
      create(:sat_unit_key, code: 'KG')

      duplicate = build(:sat_unit_key, code: 'kg')
      expect(duplicate).not_to be_valid
    end

    it 'allows symbol to be blank' do
      unit_key.symbol = ''
      expect(unit_key).to be_valid
    end

    it 'validates date range' do
      unit_key.valid_from = Date.current
      unit_key.valid_to = Date.yesterday

      expect(unit_key).not_to be_valid
      expect(unit_key.errors[:valid_to]).to be_present
    end
  end

  # =========================
  # SCOPES
  # =========================
  describe 'scopes' do
    describe '.active' do
      it 'returns only non-deleted records' do
        active = create(:sat_unit_key)
        create(:sat_unit_key, :deleted)

        expect(SatUnitKey.active).to include(active)
        expect(SatUnitKey.active.count).to eq(1)
      end
    end

    describe '.valid_on' do
      it 'returns records valid for a given date' do
        valid = create(:sat_unit_key, :with_valid_range)
        create(:sat_unit_key, :expired)

        result = SatUnitKey.valid_on(Date.current)

        expect(result).to include(valid)
        expect(result.count).to eq(1)
      end
    end

    describe '.ordered' do
      it 'orders by code' do
        create(:sat_unit_key, code: 'ZZZ')
        create(:sat_unit_key, code: 'AAA')

        first = SatUnitKey.ordered.first!

        expect(first.code).to eq('AAA')
      end
    end
  end

  # =========================
  # METHODS
  # =========================
  describe 'instance methods' do
    describe '#active?' do
      it 'returns true if not deleted' do
        expect(unit_key.active?).to be true
      end

      it 'returns false if deleted' do
        unit_key.deleted_at = Time.current
        expect(unit_key.active?).to be false
      end
    end

    describe '#valid_for_date?' do
      it 'returns true if within range' do
        unit_key.valid_from = Date.yesterday
        unit_key.valid_to = Date.tomorrow

        expect(unit_key.valid_for_date?).to be true
      end

      it 'returns false if outside range' do
        unit_key.valid_from = Date.tomorrow

        expect(unit_key.valid_for_date?).to be false
      end
    end

    describe '#to_label' do
      it 'includes symbol when present' do
        unit_key.symbol = 'kg'
        expect(unit_key.to_label).to include('(kg)')
      end

      it 'excludes symbol when blank' do
        unit_key.symbol = nil
        expect(unit_key.to_label).not_to include('()')
      end
    end
  end

  # =========================
  # CLASS METHODS
  # =========================
  describe '.for_code' do
    it 'returns valid record for date' do
      record = create(:sat_unit_key, :with_valid_range, code: 'KG')

      result = SatUnitKey.for_code('kg', Date.current)

      expect(result).to eq(record)
    end

    it 'returns nil if not found' do
      expect(SatUnitKey.for_code('XXX')).to be_nil
    end
  end

  # =========================
  # CALLBACKS
  # =========================
  describe 'callbacks' do
    it 'normalizes fields before validation' do
      unit_key.code = ' kg '
      unit_key.description = ' test '
      unit_key.symbol = ' kg '

      unit_key.validate

      expect(unit_key.code).to eq('KG')
      expect(unit_key.description).to eq('test')
      expect(unit_key.symbol).to eq('kg')
    end
  end
end
