require 'rails_helper'

RSpec.describe Branch, type: :model do
  describe 'associations' do
    it { is_expected.to have_one(:address).dependent(:destroy) }
    it { is_expected.to have_many(:user_roles).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:users).through(:user_roles) }
  end

  describe 'nested address' do
    it 'accepts nested address attributes' do
      branch = build(:branch)
      branch.build_address(
        street: 'Av. Reforma',
        city: 'Cuautitlán',
        state: 'Estado de México',
        country: 'MX',
        postal_code: '54800'
      )

      expect(branch).to be_valid
    end
  end
end
