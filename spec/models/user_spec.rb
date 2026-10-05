# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#admin?' do
    let(:user) { create(:user) }
    it 'recognizes administrator' do
      role=create(:system_role,:system,code:'administrator'); create(:user_role,user:,system_role:role)
      expect(user.admin?).to be(true)
    end
    it 'recognizes super admin' do
      role=create(:system_role,:system,code:'super_admin'); create(:user_role,user:,system_role:role)
      expect(user.admin?).to be(true)
    end
    it 'returns false without admin role' do
      expect(user.admin?).to be(false)
    end
  end

  describe '#role?' do
    let(:user) { create(:user) }
    let(:role) { create(:system_role,:system,code:'sales') }
    it 'recognizes a matching role' do
      create(:user_role,user:,system_role:role); expect(user.role?('sales')).to be(true)
    end
    it 'returns false without role' do
      expect(user.role?('sales')).to be(false)
    end
    it 'filters by branch' do
      branch=create(:branch); create(:user_role,user:,system_role:role,branch:)
      expect(user.role?('sales',branch:)).to be(true)
      expect(user.role?('sales',branch:create(:branch))).to be(false)
    end
  end

  describe '#permission?' do
    let(:user) { create(:user) }
    let(:role) { create(:system_role,:system,code:'administrator') }
    let(:permission) { create(:permission,code:'categories.access') }
    before { create(:user_role,user:,system_role:role) }
    it 'recognizes active permission' do
      create(:system_role_permission,system_role:role,permission:)
      expect(user.permission?('categories.access')).to be(true)
    end
    it 'returns false without permission' do
      expect(user.permission?('categories.access')).to be(false)
    end
    it 'rejects inactive permission' do
      permission.update!(status: :inactive); create(:system_role_permission,system_role:role,permission:)
      expect(user.permission?('categories.access')).to be(false)
    end
  end

  describe '#initials and #display_name' do
    it 'uses username' do
      user=build(:user,username:'John Doe',email:'john.doe@example.com')
      expect(user.initials).to eq('JD'); expect(user.display_name).to eq('John Doe')
    end
    it 'falls back to email' do
      user=build(:user,username:nil,email:'john.doe@example.com')
      expect(user.initials).to eq('JD'); expect(user.display_name).to eq('JD')
    end
  end

  describe 'email validation' do
    subject(:user) { build(:user) }
    it 'accepts valid email' do
      user.email='user@example.com'; expect(user).to be_valid
    end
    it 'rejects invalid email' do
      user.email='invalid-email'; expect(user).to be_invalid; expect(user.errors[:email]).to be_present
    end
  end

  describe '.online_user_ids and #online?' do
    it 'converts ids to integers' do
      kredis_set=instance_double('KredisSet',members:%w[1 2])
      allow(Kredis).to receive(:set).with(User::ONLINE_USERS_KEY).and_return(kredis_set)
      expect(User.online_user_ids).to eq([1,2])
    end
    it 'returns true online' do
      allow(User).to receive(:online_user_ids).and_return([7]); expect(build(:user,id:7).online?).to be(true)
    end
    it 'returns false offline' do
      allow(User).to receive(:online_user_ids).and_return([]); expect(build(:user,id:7).online?).to be(false)
    end
  end
end
