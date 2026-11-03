# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Concurrent user invitation activation', :concurrent_db do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, status: :pending) }

  before { create(:organization_membership, user:, organization:, account_status: :pending) }

  it 'accepts the same token exactly once across simultaneous database connections' do
    invitation = UserInvitation.issue!(user:, organization:)
    start = Queue.new
    results = Queue.new
    workers = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          attempt = UserInvitation.find(invitation.id)
          results << attempt.accept!(
            token: invitation.raw_token,
            password: 'securepassword123',
            password_confirmation: 'securepassword123'
          )
        rescue StandardError => e
          results << e
        end
      end
    end
    2.times { start << true }
    workers.each(&:join)

    outcomes = Array.new(2) { results.pop }
    expect(outcomes.grep(StandardError)).to be_empty
    expect(outcomes.count(true)).to eq(1)
    expect(invitation.reload.accepted_at).to be_present
    expect(user.reload).to be_active
  end

  it 'leaves only the newest token valid after concurrent resends' do
    start = Queue.new
    results = Queue.new
    workers = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          results << UserInvitation.issue!(user: User.find(user.id), organization:)
        rescue StandardError => e
          results << e
        end
      end
    end
    2.times { start << true }
    workers.each(&:join)

    invitations = Array.new(2) { results.pop }
    expect(invitations.grep(StandardError)).to be_empty
    expect(invitations.count(&:usable?)).to eq(1)
  end
end
