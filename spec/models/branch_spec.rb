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
    it 'stores a primary mobile in the polymorphic phones association' do
      branch = build(:branch)
      mobile = branch.phones.build(number: '55 1234 5678', kind: 'mobile', primary: true)

      expect(branch).to be_valid
      expect(mobile.number).to eq('+525512345678')
    end
    it 'accepts both boolean status values' do
      expect(build(:branch, status: true)).to be_valid
      expect(build(:branch, status: false)).to be_valid
    end

    it 'requires unique branch names within an organization' do
      organization = create(:organization)
      create(:branch, organization:, name: 'Centro')

      branch = build(:branch, organization:, name: 'centro')

      expect(branch).not_to be_valid
      expect(branch.errors[:name]).to include('has already been taken')
    end
  end

  describe 'nested address' do
    it 'accepts nested address attributes' do
      branch = build(:branch)
      branch.build_address(
        street: 'Av. Reforma',
        exterior_number: '100',
        neighborhood: 'Centro',
        city: 'Cuautitlán',
        state: 'Estado de México',
        country: build(:country, iso_alpha2: 'MX'),
        postal_code: '54800'
      )

      expect(branch).to be_valid
    end
  end
end
