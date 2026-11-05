# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPermissionsHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :blocked) }
  let(:actor) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(actor)
    allow(actor).to receive(:permission?).and_return(false)
    helper.define_singleton_method(:policy) { |record| Pundit.policy!(current_user, record) }
  end

  it 'hides all status actions from unauthorized actors' do
    expect(helper.allowed_user_transitions(user, organization:)).to be_empty
  end

  it 'requires unblock permission to return a blocked account to its previous state' do
    create(:organization_membership, user:, organization:, account_status: :blocked)
    UserStatusEvent.create!(user:, actor:, organization:, from_status: 'active', to_status: 'blocked', reason: 'Review')
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    allow(actor).to receive(:permission?).with('users.unblock').and_return(true)
    expect(helper.allowed_user_transitions(user, organization:)).to eq(['active'])
  end

  it 'offers no actions when the target has no membership in this organization' do
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'administrator'))
    expect(helper.allowed_user_transitions(user, organization:)).to be_empty
  end
end
