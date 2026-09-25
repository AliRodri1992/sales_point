require 'rails_helper'

RSpec.describe Branch, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:user_roles).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:users).through(:user_roles) }
  end
end
