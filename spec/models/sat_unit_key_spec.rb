# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SatUnitKey, type: :model do
  subject(:unit_key){build(:sat_unit_key)}

  describe 'validations' do
    it 'is valid with valid attributes'{expect(unit_key).to be_valid}
    it 'normalizes lowercase code'{unit_key.code='abc'; expect(unit_key).to be_valid; expect(unit_key.code).to eq('ABC')}
    it 'rejects invalid format'{unit_key.code='abc-123'; expect(unit_key).not_to be_valid}
    it 'requires description'{unit_key.description=nil; expect(unit_key).not_to be_valid}
    it 'rejects duplicate active codes'{create(:sat_unit_key,code:'KG'); expect(build(:sat_unit_key,code:'kg')).not_to be_valid}
    it 'allows blank symbol'{unit_key.symbol=''; expect(unit_key).to be_valid}
    it 'rejects invalid date range'{unit_key.valid_from=Date.current; unit_key.valid_to=Date.yesterday; expect(unit_key).not_to be_valid}
  end

  describe 'scopes' do
    it 'filters active'{active=create(:sat_unit_key); deleted=create(:sat_unit_key,:deleted); expect(described_class.active).to include(active); expect(described_class.active).not_to include(deleted)}
    it 'filters by date'{valid=create(:sat_unit_key,:with_valid_range); expired=create(:sat_unit_key,:expired); expect(described_class.valid_on(Date.current)).to include(valid); expect(described_class.valid_on(Date.current)).not_to include(expired)}
    it 'orders by code'{create(:sat_unit_key,code:'ZZZ'); create(:sat_unit_key,code:'AAA'); expect(described_class.ordered.first!.code).to eq('AAA')}
  end

  describe '#active?' do
    it 'returns true when not deleted'{expect(unit_key.active?).to be(true)}
    it 'returns false when deleted'{unit_key.deleted_at=Time.current; expect(unit_key.active?).to be(false)}
  end

  describe '#valid_for_date?' do
    it 'accepts bounded range'{unit_key.valid_from=Date.yesterday; unit_key.valid_to=Date.tomorrow; expect(unit_key.valid_for_date?).to be(true)}
    it 'rejects before start'{unit_key.valid_from=Date.tomorrow; expect(unit_key.valid_for_date?(Date.current)).to be(false)}
    it 'accepts open start'{unit_key.valid_from=nil; unit_key.valid_to=Date.tomorrow; expect(unit_key.valid_for_date?).to be(true)}
    it 'accepts open end'{unit_key.valid_from=Date.yesterday; unit_key.valid_to=nil; expect(unit_key.valid_for_date?).to be(true)}
    it 'accepts open range'{unit_key.valid_from=nil; unit_key.valid_to=nil; expect(unit_key.valid_for_date?).to be(true)}
  end

  describe '#to_label' do
    it 'includes symbol'{unit_key.symbol='kg'; expect(unit_key.to_label).to include('(kg)')}
    it 'omits blank symbol'{unit_key.symbol=nil; expect(unit_key.to_label).to eq("#{unit_key.code} - #{unit_key.description}")}
  end

  describe '#soft_delete!' do
    it 'sets deletion metadata'{record=create(:sat_unit_key); expect(record.soft_delete!(123)).to be(true); expect(record.reload.deleted_at).to be_present; expect(record.deleted_by).to eq(123)}
  end

  describe '.for_code' do
    it 'normalizes lookup code'{record=create(:sat_unit_key,code:'KG'); expect(described_class.for_code(' kg ')).to eq(record)}
    it 'returns nil when not found'{expect(described_class.for_code('XXX')).to be_nil}
  end

  describe 'callbacks' do
    it 'normalizes all fields'{unit_key.code=' kg '; unit_key.description=' test '; unit_key.symbol=' kg '; unit_key.validate; expect(unit_key.code).to eq('KG'); expect(unit_key.description).to eq('test'); expect(unit_key.symbol).to eq('kg')}
  end
end