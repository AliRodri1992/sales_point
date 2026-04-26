require 'rails_helper'

RSpec.describe SatMonth, type: :model do
  let(:sat_month) { build(:sat_month) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(sat_month).to be_valid
    end

    it 'is invalid without code' do
      sat_month.code = nil
      expect(sat_month).not_to be_valid
    end

    it 'is invalid with invalid code format' do
      sat_month.code = '13'
      expect(sat_month).not_to be_valid
    end

    it 'is invalid without description' do
      sat_month.description = nil
      expect(sat_month).not_to be_valid
    end

    it 'is invalid with month_number out of range' do
      sat_month.month_number = 13
      expect(sat_month).not_to be_valid
    end

    it 'is invalid when code does not match month_number' do
      sat_month.code = '06'
      sat_month.month_number = 5

      expect(sat_month).not_to be_valid
    end

    it 'is valid when code matches month_number' do
      sat_month.code = '05'
      sat_month.month_number = 5

      expect(sat_month).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_month) do
      create(:sat_month, status: true, deleted_at: nil, month_number: 1, code: '01')
    end

    let!(:deleted_month) do
      create(:sat_month, status: true, deleted_at: Time.current, month_number: 2, code: '02')
    end

    it 'returns only not deleted records' do
      expect(SatMonth.not_deleted).to include(active_month)
      expect(SatMonth.not_deleted).not_to include(deleted_month)
    end

    it 'returns only active records' do
      expect(SatMonth.active).to include(active_month)
      expect(SatMonth.active).not_to include(deleted_month)
    end

    it 'orders by month_number' do
      create(:sat_month, month_number: 12, code: '12')
      create(:sat_month, month_number: 1, code: '01')

      first_month = SatMonth.ordered.first!

      expect(first_month.month_number).to eq(1)
    end
  end

  describe '#month_name' do
    it 'returns correct month name' do
      sat_month.month_number = 1
      expect(sat_month.month_name).to eq('January')
    end
  end

  describe '#to_label' do
    it 'returns formatted label with description' do
      sat_month.code = '01'
      sat_month.description = 'January'

      expect(sat_month.to_label).to eq('01 - January')
    end

    it 'returns fallback month name when description is blank' do
      sat_month.code = '01'
      sat_month.description = nil
      sat_month.month_number = 1

      expect(sat_month.to_label).to eq('01 - January')
    end
  end
end
