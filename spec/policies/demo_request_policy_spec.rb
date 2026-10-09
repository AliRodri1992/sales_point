# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequestPolicy, type: :policy do
  subject(:policy) { described_class.new(user, demo_request) }

  let(:demo_request) { build(:demo_request) }
  let(:user) { create(:user) }

  context 'when the user is an administrator' do
    before do
      role = create(:system_role, :system, code: 'administrator', status: 'active')
      user.system_roles << role
    end

    it { expect(policy).to be_present }
    it { expect(policy.index?).to be true }
    it { expect(policy.show?).to be true }
    it { expect(policy.update?).to be true }
  end

  context 'when the user is not an administrator' do
    it { expect(policy.index?).to be false }
    it { expect(policy.show?).to be false }
    it { expect(policy.update?).to be false }
  end
end
