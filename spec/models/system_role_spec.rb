require 'rails_helper'

RSpec.describe SystemRole, type: :model do
  subject { build(:system_role) }

  # =========================
  # VALIDATIONS
  # =========================
  it 'is valid with valid attributes' do
    expect(subject).to be_valid
  end

  it 'is invalid without name' do
    subject.name = nil
    expect(subject).not_to be_valid
  end

  it 'validates uniqueness of name scoped to role_type' do
    create(:system_role, name: 'Admin', role_type: :system)

    duplicate = build(:system_role, name: 'Admin', role_type: :system)

    expect(duplicate).not_to be_valid
  end

  # =========================
  # ENUMS
  # =========================
  it 'has valid role_types' do
    expect(SystemRole.role_types.keys).to include('system', 'branch')
  end

  it 'has valid statuses' do
    expect(SystemRole.statuses.keys).to include('active', 'inactive', 'deprecated')
  end

  # =========================
  # SCOPES (Faker-powered data)
  # =========================
  describe 'scopes' do
    before do
      create_list(:system_role, 3, :active)
      create_list(:system_role, 2, :inactive)
      create_list(:system_role, 1, :deprecated)
    end

    it '.active returns active roles' do
      expect(SystemRole.active.count).to eq(3)
    end

    it '.inactive returns inactive roles' do
      expect(SystemRole.inactive.count).to eq(2)
    end

    it '.deprecated returns deprecated roles' do
      expect(SystemRole.deprecated.count).to eq(1)
    end
  end

  # =========================
  # INSTANCE METHODS
  # =========================
  describe 'status helpers' do
    it 'detects active role' do
      role = build(:system_role, :active)
      expect(role.active?).to be true
    end

    it 'detects inactive role' do
      role = build(:system_role, :inactive)
      expect(role.inactive?).to be true
    end
  end

  # =========================
  # FAKER REALISTIC TEST
  # =========================
  it 'generates realistic roles with Faker' do
    role = create(:system_role)

    expect(role.name).to be_present
    expect(role.description).to be_a(String)
    expect(SystemRole.role_types.keys).to include(role.role_type)
    expect(SystemRole.statuses.keys).to include(role.status)
  end
end
