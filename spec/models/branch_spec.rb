require 'rails_helper'

RSpec.describe Branch, type: :model do
  describe 'associations' do
    it { is_expected.to have_one(:address).dependent(:destroy) }
    it { is_expected.to have_many(:user_roles).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:users).through(:user_roles) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_least(3).is_at_most(150) }
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

  it 'allows only the registration bootstrap to create a provisional address-less branch' do
    branch = build(:branch, :without_address)
    branch.registration_bootstrap = true
    expect(branch).to be_valid

    branch.registration_bootstrap = false
    expect(branch).not_to be_valid
    expect(branch.errors[:address]).to be_present
  end

  it 'requires an address when registering a branch directly through the model' do
    branch = build(:branch, :without_address)

    expect(branch).not_to be_valid
    expect(branch.errors[:address]).to be_present
  end

  it 'enforces the branch name length on the model without browser constraints' do
    branch = build(:branch, name: 'AB')
    expect(branch).not_to be_valid
    expect(branch.errors[:name]).to be_present

    branch.name = 'A' * 151
    expect(branch).not_to be_valid

    branch.name = 'A' * 150
    expect(branch).to be_valid
  end

  it 'protects the last active branch and requires reassignment before deactivation' do
    organization = create(:organization)
    branch = create(:branch, organization:, name: 'Central')
    fallback = create(:branch, organization:, name: 'Fallback')
    person = create(:user)
    create(:organization_membership, organization:, user: person)
    role = create(:user_role, user: person, branch:, system_role: create(:system_role, :branch))

    expect(branch.update(status: false)).to be(false)
    expect(branch.errors[:status]).to be_present

    role.update!(deleted_at: Time.current)
    expect(branch.update(status: false)).to be(true)

    expect(fallback.update(status: false)).to be(false)
    expect(fallback.errors[:status]).to be_present
  end

  it 'prevents soft deletion while a branch still has assigned users' do
    branch = create(:branch)
    person = create(:user)
    create(:organization_membership, organization: branch.organization, user: person)
    create(:user_role, user: person, branch:, system_role: create(:system_role, :branch))

    expect(branch.update(deleted_at: Time.current)).to be(false)
    expect(branch.errors[:base]).to be_present
    expect(branch.reload.deleted_at).to be_nil
  end

  it 'does not allow deactivation with live terminals or untransferred stock' do
    organization = create(:organization)
    branch = create(:branch, organization:, name: 'Operations')
    create(:branch, organization:, name: 'Available')
    terminal = Terminal.create!(branch:, name: 'Cash register', code: 'POS-01', status: 'active')

    expect(branch.update(status: false)).to be(false)
    expect(branch.errors[:status]).to be_present

    terminal.update!(status: 'inactive')
    product = create(:product, organization:)
    inventory = Inventory.create!(branch:, organization:, product:, stock: 7, min_stock: 0)
    expect(branch.update(status: false)).to be(false)

    inventory.update!(stock: 0)
    expect(branch.update(status: false)).to be(true)
  end
end
