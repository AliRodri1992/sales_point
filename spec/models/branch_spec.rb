require 'rails_helper'

RSpec.describe Branch, type: :model do
  describe 'associations' do
    it { is_expected.to have_one(:address).dependent(:destroy) }
    it { is_expected.to have_many(:user_roles).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:branch_status_transitions).dependent(:restrict_with_exception) }
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

  it 'records the initial operational status without an actor' do
    branch = create(:branch, operational_state: 'preparing')
    expect(branch.branch_status_transitions.count).to eq(1)
    expect(branch.branch_status_transitions.first).to have_attributes(
      from_status: nil, to_status: 'preparing', changed_by: nil
    )
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

  it 'protects the last active branch during an audited suspension' do
    organization = create(:organization, onboarding_status: 'completed')
    branch = create(:branch, organization:, name: 'Central')
    fallback = create(:branch, organization:, name: 'Fallback')
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: admin)

    expect do
      Branches::TransitionStatus.call(branch:, actor: admin, to: 'suspended', reason: 'Maintenance')
    end.not_to raise_error
    expect(branch.reload).to be_suspended
    expect(branch.status).to be(false)

    expect do
      Branches::TransitionStatus.call(branch: fallback, actor: admin, to: 'suspended',
                                      reason: 'Maintenance')
    end.to raise_error(Branches::TransitionStatus::InvalidTransition)
    expect(fallback.reload).to be_active
  end

  it 'allows soft deletion of a preparing branch and retains its initial audit history' do
    branch = create(:branch, operational_state: 'preparing')
    initial_event = branch.branch_status_transitions.sole

    expect(branch.update(deleted_at: Time.current)).to be(true)
    expect(branch.reload.deleted_at).to be_present
    expect(BranchStatusTransition.unscoped.find(initial_event.id).to_status).to eq('preparing')
  end

  it 'keeps the branch identifier stable when blank or changed on update' do
    branch = create(:branch)
    original = branch.code

    expect(branch.update(code: '')).to be(false)
    expect(branch.errors[:code]).to be_present
    expect(branch.reload.code).to eq(original)

    expect(branch.update(name: 'Central Updated')).to be(true)
    expect(branch.reload.code).to eq(original)
  end

  it 'requires a complete address after activation and prevents its removal' do
    branch = create(:branch)
    address = branch.address
    address.city = ''
    expect(branch).not_to be_valid
    expect(branch.errors[:address]).to be_present

    address.reload
    expect(address.destroy).to be(false)
    expect(address.reload.deleted_at).to be_nil
    expect(address.update(deleted_at: Time.current)).to be(false)
    expect(address.reload.deleted_at).to be_nil
  end

  it 'also requires a valid address for a suspended branch' do
    branch = create(:branch)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization: branch.organization, user: admin)
    Branches::TransitionStatus.call(branch:, actor: admin, to: 'suspended', reason: 'Maintenance')

    branch.address.city = ''
    expect(branch).not_to be_valid
    expect(branch.errors[:address]).to be_present
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

  it 'prevents closure with terminal activity or stock' do
    organization = create(:organization)
    branch = create(:branch, organization:, name: 'Operations')
    create(:branch, organization:, name: 'Available')
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization:, user: admin)
    terminal = Terminal.create!(branch:, name: 'Cash register', code: 'POS-01', status: 'active')

    expect do
      Branches::TransitionStatus.call(branch:, actor: admin, to: 'closed', reason: 'Closure')
    end.to raise_error(Branches::TransitionStatus::InvalidTransition)

    terminal.update!(status: 'inactive')
    product = create(:product, organization:)
    inventory = Inventory.create!(branch:, organization:, product:, stock: 7, min_stock: 0)
    expect do
      Branches::TransitionStatus.call(branch:, actor: admin, to: 'closed', reason: 'Closure')
    end.to raise_error(Branches::TransitionStatus::InvalidTransition)

    inventory.update!(stock: 0)
    expect do
      Branches::TransitionStatus.call(branch:, actor: admin, to: 'closed', reason: 'Closure')
    end.not_to raise_error
    expect(branch.reload).to be_closed
    expect(branch.branch_status_transitions.last.to_status).to eq('closed')
  end

  it 'rejects stale branch edits submitted after a concurrent closure' do
    branch = create(:branch, name: 'Initial office')
    stale = Branch.find(branch.id)
    admin = create(:user, system_roles: [create(:system_role, :system, code: 'administrator')])
    create(:organization_membership, organization: branch.organization, user: admin)
    Branches::TransitionStatus.call(
      branch:, actor: admin, to: 'closed', reason: 'Final closure'
    )

    stale.name = 'Late edit'
    expect { stale.save! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(branch.reload.name).to eq('Initial office')
  end

  it 'rejects a lifecycle change outside the transition service' do
    branch = create(:branch)
    expect(branch.update(operational_status: 'closed')).to be(false)
    expect(branch.errors[:operational_status]).to be_present
    expect(branch.reload).to be_active
  end
end
