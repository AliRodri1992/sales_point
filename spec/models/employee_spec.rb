# frozen_string_literal: true

RSpec.describe Employee, type: :model do
  subject(:employee) { build(:employee) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_one(:user) }
  it { is_expected.to validate_presence_of(:first_name) }
  it { is_expected.to validate_presence_of(:last_name) }
  it { is_expected.to validate_presence_of(:email) }
end
