# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardPreference, type: :model do
  subject(:dashboard_preference) { build(:dashboard_preference, user: create(:user)) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:grid_type) }
    it { is_expected.to validate_presence_of(:widget_id) }

    it do
      is_expected.to validate_numericality_of(:position_x)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it do
      is_expected.to validate_numericality_of(:position_y)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it do
      is_expected.to validate_numericality_of(:width)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it do
      is_expected.to validate_numericality_of(:height)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it do
      is_expected.to validate_inclusion_of(:grid_type)
        .in_array(%w[kpi main])
    end

    it do
      is_expected.to validate_uniqueness_of(:widget_id)
        .scoped_to(:user_id)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:dashboard_preference)).to be_valid
    end
  end
end
