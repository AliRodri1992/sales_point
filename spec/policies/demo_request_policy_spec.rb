# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequestPolicy, type: :policy do
  subject(:policy) { described_class.new(user, demo_request) }

  let(:demo_request) { build(:demo_request) }
  let(:user) { build(:user) }

  context 'when the user is an administrator' do
    before do
      role = build(:system_role, :system, code: 'administrator')
      user.system_roles << role
    end

    it { is_expected.to permit_actions(:index, :show, :update) }
  end

  context 'when the user is not an administrator' do
    it { is_expected.to forbid_actions(:index, :show, :update) }
  end
end
