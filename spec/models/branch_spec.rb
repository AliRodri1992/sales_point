require 'rails_helper'

RSpec.describe Branch, type: :model do
  describe 'associations' do
    it { is_expected.to have_one(:address).dependent(:destroy) }
    it { is_expected.to have_many(:user_roles).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:users).through(:user_roles) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { is_expected.to allow_value('5551234567').for(:phone) }
    it { is_expected.to allow_value('+52 55 5123 4567').for(:phone) }
    it { is_expected.not_to allow_value('abc123').for(:phone) }
    it { is_expected.to validate_length_of(:phone).is_at_least(7).is_at_most(20).allow_blank }
    it { is_expected.to validate_inclusion_of(:status).in_array([true, false]) }
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
