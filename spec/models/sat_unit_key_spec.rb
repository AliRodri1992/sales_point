# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SatUnitKey, type: :model do
  subject(:unit_key) { build(:sat_unit_key) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(unit_key).to be_valid
    end

    it 'normalizes lowercase code' do
      unit_key.code = 'abc'

      expect(unit_key).to be_valid
      expect(unit_key.code).to eq('ABC')
    end

    it 'rejects invalid format' do
      unit_key.code = 'abc-123'

      expect(unit_key).not_to be_valid
    end

    it 'requires description' do
      unit_key.description = nil

      expect(unit_key).not_to be_valid
    end

    it 'rejects duplicate active codes' do
      create(:sat_unit_key, code: 'KG')

      expect(build(:sat_unit_key, code: 'kg')).not_to be_valid
    end

    it 'allows blank symbol' do
      unit_key.symbol = ''

      expect(unit_key).to be_valid
    end

    it 'rejects invalid date range' do
      unit_key.valid_from = Date.current
      unit_key.valid_to = Date.yesterday

      expect(unit_key).not_to be_valid
    end
  end

  describe 'scopes' do
    it 'filters active' do
      active = create(:sat_unit_key)
      deleted = create(:sat_unit_key, :deleted)

      expect(described_class.active).to include(active)
      expect(described_class.active).not_to include(deleted)
    end

    it 'filters by date' do
      valid = create(:sat_unit_key, :with_valid_range)
      expired = create(:sat_unit_key, :expired)

      expect(described_class.valid_on(Date.current)).to include(valid)
      expect(described_class.valid_on(Date.current)).not_to include(expired)
    end

    it 'orders by code' do
      create(:sat_unit_key, code: 'ZZZ')
      create(:sat_unit_key, code: 'AAA')

      expect(described_class.ordered.first!.code).to eq('AAA')
    end
  end

  describe '#active?' do
    it 'returns true when not deleted' do
      expect(unit_key.active?).to be(true)
    end

    it 'returns false when deleted' do
      unit_key.deleted_at = Time.current

      expect(unit_key.active?).to be(false)
    end
  end

  describe '#valid_for_date?' do
    it 'accepts bounded range' do
      unit_key.valid_from = Date.yesterday
      unit_key.valid_to = Date.tomorrow

      expect(unit_key.valid_for_date?).to be(true)
    end

    it 'rejects before start' do
      unit_key.valid_from = Date.tomorrow

      expect(unit_key.valid_for_date?(Date.current)).to be(false)
    end

    it 'accepts open start' do
      unit_key.valid_from = nil
      unit_key.valid_to = Date.tomorrow

      expect(unit_key.valid_for_date?).to be(true)
    end

    it 'accepts open end' do
      unit_key.valid_from = Date.yesterday
      unit_key.valid_to = nil

      expect(unit_key.valid_for_date?).to be(true)
    end

    it 'accepts open range' do
      unit_key.valid_from = nil
      unit_key.valid_to = nil

      expect(unit_key.valid_for_date?).to be(true)
    end
  end

  describe '#to_label' do
    it 'includes symbol' do
      unit_key.symbol = 'kg'

      expect(unit_key.to_label).to include('(kg)')
    end

    it 'omits blank symbol' do
      unit_key.symbol = nil

      expect(unit_key.to_label).to eq("#{unit_key.code} - #{unit_key.description}")
    end
  end

  describe '#soft_delete!' do
    it 'sets deletion metadata' do
      record = create(:sat_unit_key)

      expect(record.soft_delete!(123)).to be(true)
      expect(record.reload.deleted_at).to be_present
      expect(record.deleted_by).to eq(123)
    end
  end

  describe '.for_code' do
    it 'normalizes lookup code' do
      record = create(:sat_unit_key, code: 'KG')

      expect(described_class.for_code(' kg ')).to eq(record)
    end

    it 'returns nil when not found' do
      expect(described_class.for_code('XXX')).to be_nil
    end
  end

  describe 'callbacks' do
    it 'normalizes all fields' do
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
