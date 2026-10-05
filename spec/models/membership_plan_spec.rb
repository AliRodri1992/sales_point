# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipPlan, type: :model do
  describe 'validations', skip: 'requires database connection' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:currency) }
  end

  describe 'enums', skip: 'requires database connection' do
    it { is_expected.to define_enum_for(:billing_interval).with_values(monthly: 'monthly', yearly: 'yearly') }
  end

  describe 'associations', skip: 'requires database connection' do
    it { is_expected.to have_many(:membership_plan_features).dependent(:destroy) }
    it { is_expected.to have_many(:membership_features).through(:membership_plan_features) }
  end
end
