# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SatMonth, type: :model do
  let(:sat_month) { build(:sat_month) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(sat_month).to be_valid
    end

    it 'rejects missing code' do
      sat_month.code = nil
      expect(sat_month).not_to be_valid
    end

    it 'rejects invalid code' do
      sat_month.code = '13'
      expect(sat_month).not_to be_valid
    end

    it 'rejects missing description' do
      sat_month.description = nil
      expect(sat_month).not_to be_valid
    end

    it 'rejects out of range month number' do
      sat_month.month_number = 13
      expect(sat_month).not_to be_valid
    end

    it 'rejects mismatched code' do
      sat_month.code = '06'
      sat_month.month_number = 5
      expect(sat_month).not_to be_valid
    end

    it 'accepts matching code' do
      sat_month.code = '05'
      sat_month.month_number = 5
      expect(sat_month).to be_valid
    end

    it 'rejects invalid date range' do
      sat_month.valid_from = Date.current
      sat_month.valid_to = Date.yesterday
      expect(sat_month).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_month) do
      create(:sat_month, status: true, deleted_at: nil, month_number: 1, code: '01')
    end
    let!(:deleted_month) do
      create(:sat_month, status: true, deleted_at: Time.current, month_number: 2, code: '02')
    end

    it 'filters deleted records' do
      expect(described_class.not_deleted).to include(active_month)
      expect(described_class.not_deleted).not_to include(deleted_month)
    end

    it 'filters inactive records' do
      expect(described_class.active).to include(active_month)
      expect(described_class.active).not_to include(deleted_month)
    end

    it 'orders by month number' do
      create(:sat_month, month_number: 12, code: '12')
      create(:sat_month, month_number: 3, code: '03')

      expect(described_class.ordered.first!).to eq(active_month)
    end

    it 'filters by date' do
      current = create(
        :sat_month,
        month_number: 3,
        code: '03',
        valid_from: Date.yesterday,
        valid_to: Date.tomorrow
      )

      expect(described_class.valid_on(Date.current)).to include(current)
    end

    it 'returns current active months' do
      current = create(:sat_month, status: true, month_number: 4, code: '04')

      expect(described_class.current).to include(current)
    end
  end

  describe '#active?' do
    it 'returns true when active' do
      sat_month.status = true
      sat_month.deleted_at = nil

      expect(sat_month.active?).to be(true)
    end

    it 'returns false when deleted' do
      sat_month.status = true
      sat_month.deleted_at = Time.current

      expect(sat_month.active?).to be(false)
    end

    it 'returns false when inactive' do
      sat_month.status = false
      sat_month.deleted_at = nil

      expect(sat_month.active?).to be(false)
    end
  end

  describe '#valid_for_date?' do
    it 'accepts bounded range' do
      sat_month.valid_from = Date.yesterday
      sat_month.valid_to = Date.tomorrow

      expect(sat_month.valid_for_date?).to be(true)
    end

    it 'rejects before start' do
      sat_month.valid_from = Date.tomorrow

      expect(sat_month.valid_for_date?(Date.current)).to be(false)
    end

    it 'accepts open start' do
      sat_month.valid_from = nil
      sat_month.valid_to = Date.tomorrow

      expect(sat_month.valid_for_date?).to be(true)
    end

    it 'accepts open end' do
      sat_month.valid_from = Date.yesterday
      sat_month.valid_to = nil

      expect(sat_month.valid_for_date?).to be(true)
    end

    it 'accepts fully open range' do
      sat_month.valid_from = nil
      sat_month.valid_to = nil

      expect(sat_month.valid_for_date?).to be(true)
    end
  end

  describe '#month_name and #to_label' do
    it 'returns month name' do
      sat_month.month_number = 1

      expect(sat_month.month_name).to eq('January')
    end

    it 'uses description' do
      sat_month.code = '01'
      sat_month.description = 'January'

      expect(sat_month.to_label).to eq('01 - January')
    end

    it 'falls back to month name' do
      sat_month.code = '01'
      sat_month.description = nil
      sat_month.month_number = 1

      expect(sat_month.to_label).to eq('01 - January')
    end
  end

  describe '.for_code' do
    it 'finds active month' do
      month = create(:sat_month, code: '07', month_number: 7)

      expect(described_class.for_code('07')).to eq(month)
    end

    it 'returns nil for unknown code' do
      expect(described_class.for_code('99')).to be_nil
    end
  end

  describe 'callbacks' do
    it 'normalizes fields' do
      sat_month.code = ' 1'
      sat_month.description = ' January '
      sat_month.validate

      expect(sat_month.code).to eq('01')
      expect(sat_month.description).to eq('January')
    end

    it 'leaves blank code untouched' do
      sat_month.code = nil
      sat_month.validate

      expect(sat_month.code).to be_nil
    end
  end

  describe 'optional validity boundaries' do
    it 'accepts an open validity range when dates are missing' do
      record = build(:sat_month, valid_from: nil, valid_to: nil)

      record.valid?

      expect(record.errors[:valid_to]).to be_empty
    end
  end
end
