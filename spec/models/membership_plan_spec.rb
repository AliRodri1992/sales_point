# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipPlan, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:currency) }
  end

  describe 'enums' do
    it 'defines billing intervals' do
      expect(described_class.billing_intervals).to eq(
        'monthly' => 'monthly',
        'yearly' => 'yearly'
      )
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:membership_plan_features).dependent(:destroy) }
    it { is_expected.to have_many(:membership_features).through(:membership_plan_features) }
  end
end
