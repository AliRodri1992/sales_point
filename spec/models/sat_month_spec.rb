# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SatMonth, type: :model do
  let(:sat_month){build(:sat_month)}

  describe 'validations' do
    it 'is valid with valid attributes'{expect(sat_month).to be_valid}
    it 'rejects missing code'{sat_month.code=nil; expect(sat_month).not_to be_valid}
    it 'rejects invalid code'{sat_month.code='13'; expect(sat_month).not_to be_valid}
    it 'rejects missing description'{sat_month.description=nil; expect(sat_month).not_to be_valid}
    it 'rejects out of range month number'{sat_month.month_number=13; expect(sat_month).not_to be_valid}
    it 'rejects mismatched code'{sat_month.code='06'; sat_month.month_number=5; expect(sat_month).not_to be_valid}
    it 'accepts matching code'{sat_month.code='05'; sat_month.month_number=5; expect(sat_month).to be_valid}
    it 'rejects invalid date range'{sat_month.valid_from=Date.current; sat_month.valid_to=Date.yesterday; expect(sat_month).not_to be_valid}
  end

  describe 'scopes' do
    let!(:active_month){create(:sat_month,status:true,deleted_at:nil,month_number:1,code:'01')}
    let!(:deleted_month){create(:sat_month,status:true,deleted_at:Time.current,month_number:2,code:'02')}
    it 'filters deleted records'{expect(described_class.not_deleted).to include(active_month); expect(described_class.not_deleted).not_to include(deleted_month)}
    it 'filters inactive records'{expect(described_class.active).to include(active_month); expect(described_class.active).not_to include(deleted_month)}
    it 'orders by month number'{create(:sat_month,month_number:12,code:'12'); create(:sat_month,month_number:3,code:'03'); expect(described_class.ordered.first!).to eq(active_month)}
    it 'filters by date'{current=create(:sat_month,valid_from:Date.yesterday,valid_to:Date.tomorrow); expect(described_class.valid_on(Date.current)).to include(current)}
    it 'returns current active months'{current=create(:sat_month,status:true,month_number:4,code:'04'); expect(described_class.current).to include(current)}
  end

  describe '#active?' do
    it 'returns true when active'{sat_month.status=true; sat_month.deleted_at=nil; expect(sat_month.active?).to be(true)}
    it 'returns false when deleted'{sat_month.status=true; sat_month.deleted_at=Time.current; expect(sat_month.active?).to be(false)}
    it 'returns false when inactive'{sat_month.status=false; sat_month.deleted_at=nil; expect(sat_month.active?).to be(false)}
  end

  describe '#valid_for_date?' do
    it 'accepts bounded range'{sat_month.valid_from=Date.yesterday; sat_month.valid_to=Date.tomorrow; expect(sat_month.valid_for_date?).to be(true)}
    it 'rejects before start'{sat_month.valid_from=Date.tomorrow; expect(sat_month.valid_for_date?(Date.current)).to be(false)}
    it 'accepts open start'{sat_month.valid_from=nil; sat_month.valid_to=Date.tomorrow; expect(sat_month.valid_for_date?).to be(true)}
    it 'accepts open end'{sat_month.valid_from=Date.yesterday; sat_month.valid_to=nil; expect(sat_month.valid_for_date?).to be(true)}
    it 'accepts fully open range'{sat_month.valid_from=nil; sat_month.valid_to=nil; expect(sat_month.valid_for_date?).to be(true)}
  end

  describe '#month_name and #to_label' do
    it 'returns month name'{sat_month.month_number=1; expect(sat_month.month_name).to eq('January')}
    it 'uses description'{sat_month.code='01'; sat_month.description='January'; expect(sat_month.to_label).to eq('01 - January')}
    it 'falls back to month name'{sat_month.code='01'; sat_month.description=nil; sat_month.month_number=1; expect(sat_month.to_label).to eq('01 - January')}
  end

  describe '.for_code' do
    it 'finds active month'{month=create(:sat_month,code:'07',month_number:7); expect(described_class.for_code('07')).to eq(month)}
    it 'returns nil for unknown code'{expect(described_class.for_code('99')).to be_nil}
  end

  describe 'callbacks' do
    it 'normalizes fields'{sat_month.code=' 1'; sat_month.description=' January '; sat_month.validate; expect(sat_month.code).to eq('01'); expect(sat_month.description).to eq('January')}
    it 'leaves blank code untouched'{sat_month.code=nil; sat_month.validate; expect(sat_month.code).to be_nil}
  end
end