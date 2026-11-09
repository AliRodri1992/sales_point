# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRoles::StatusTransition do
  include ActiveSupport::Testing::TimeHelpers

  let(:actor) { create(:user) }
  let(:role) { create(:system_role, :system) }
  let!(:permission) { create(:permission, code: 'products.show') }

  before do
    create(:organization_membership, user: actor)
    create(:user_role, user: actor, system_role: create(:system_role, :system, code: 'super_admin'))
    create(:system_role_permission, system_role: role, permission:)
  end

  def transition(target, **overrides)
    token = SystemRoles::StatusReview.new(role:, actor:, target:).token
    described_class.new(role:, actor:, target:, reason: 'Reviewed access requirements',
                        review_token: token, confirmed: '1', **overrides).call!
  end

  it 'defaults new roles to inactive' do
    expect(SystemRole.new.status).to eq('inactive')
  end

  it 'suspends only this role, retains assignments and restores permissions on activation' do
    user = create(:user)
    assignment = create(:user_role, user:, system_role: role)
    other_role = create(:system_role, :system)
    other_permission = create(:permission, code: 'categories.show')
    create(:system_role_permission, system_role: other_role, permission: other_permission)
    create(:user_role, user:, system_role: other_role)

    transition('inactive')
    expect(user.permission?(permission.code)).to be(false)
    expect(user.permission?(other_permission.code)).to be(true)
    expect(assignment.reload.deleted_at).to be_nil
    expect(user.reload).to be_active
    event = role.status_events.last
    expect(event).to have_attributes(actor:, from_status: 'active', to_status: 'inactive')
    expect(event.impact).to include('users' => 1, 'without_other_roles' => 0, 'permissions' => 1)

    transition('active')
    expect(user.permission?(permission.code)).to be(true)
    expect(role.status_events.count).to eq(2)
  end

  it 'requires a current permission before activation' do
    transition('inactive')
    permission.update!(status: 'inactive')
    expect { transition('active') }.to raise_error(described_class::InvalidTransition, /permission/i)
    expect(role.reload).to be_inactive
    expect(role.status_events.count).to eq(1)
  end

  it 'requires inactive status before archiving' do
    expect { transition('deprecated') }.to raise_error(described_class::InvalidTransition, /not allowed/)
    expect(role.reload).to be_active
  end

  it 'blocks archiving while suspended users still have retained assignments' do
    user = create(:user, status: 'suspended')
    create(:user_role, user:, system_role: role)
    transition('inactive')
    expect { transition('deprecated') }.to raise_error(described_class::InvalidTransition, /assignments/)
    expect(role.reload.deleted_at).to be_nil
  end

  it 'archives and restores as inactive while preserving permissions, code and history' do
    transition('inactive')
    transition('deprecated')
    expect(role.reload).to be_deprecated
    expect(role.deleted_at).to be_present
    expect(SystemRole.available).not_to include(role)
    expect(role.permissions.reload).to include(permission)
    expect { transition('active') }.to raise_error(described_class::InvalidTransition)
    transition('inactive')
    expect(role.reload).to be_inactive
    expect(role.deleted_at).to be_nil
    expect(role.status_events.count).to eq(3)
    expect(role.permissions.reload).to include(permission)
  end

  it 'requires a nonblank reason up to 1000 characters and explicit confirmation' do
    ['', '   ', 'a' * 1001].each do |reason|
      expect { transition('inactive', reason:) }.to raise_error(described_class::InvalidTransition, /reason/)
    end
    expect { transition('inactive', confirmed: '0') }
      .to raise_error(described_class::InvalidTransition, /Confirm/)
    expect(role.reload).to be_active
    expect(role.status_events).to be_empty
  end

  it 'rejects missing, forged and expired reviews' do
    [nil, 'forged'].each do |review_token|
      expect { transition('inactive', review_token:) }.to raise_error(described_class::InvalidTransition, /review/)
    end
    token = SystemRoles::StatusReview.new(role:, actor:, target: 'inactive').token
    travel 21.minutes do
      expect { transition('inactive', review_token: token) }
        .to raise_error(described_class::InvalidTransition, /review/)
    end
    expect(role.reload).to be_active
  end

  it 'invalidates review when metadata, permissions or assignments change' do
    changes = [
      -> { role.update!(description: 'Changed since review') },
      -> { create(:system_role_permission, system_role: role) },
      -> { create(:user_role, system_role: role) }
    ]
    changes.each do |change|
      token = SystemRoles::StatusReview.new(role:, actor:, target: 'inactive').token
      change.call
      expect { transition('inactive', review_token: token) }
        .to raise_error(described_class::InvalidTransition, /review/)
    end
  end

  it 'binds review to its actor, target and role' do
    other = create(:system_role, :system)
    token = SystemRoles::StatusReview.new(role: other, actor:, target: 'inactive').token
    expect { transition('inactive', review_token: token) }.to raise_error(described_class::InvalidTransition)
    token = SystemRoles::StatusReview.new(role:, actor:, target: 'active').token
    expect { transition('inactive', review_token: token) }.to raise_error(described_class::InvalidTransition)
  end

  it 'checks authorization again inside the transaction' do
    expect { transition('inactive', actor: create(:user)) }.to raise_error(Pundit::NotAuthorizedError)
    actor.update!(status: 'blocked')
    expect { transition('inactive') }.to raise_error(Pundit::NotAuthorizedError)
  end

  it 'protects both administrative roles even when calling the service directly' do
    %w[administrator super_admin].each do |code|
      protected_role = SystemRole.find_by(code:) || create(:system_role, :system, code:)
      expect { transition('inactive', role: protected_role) }.to raise_error(Pundit::NotAuthorizedError)
      protected_role.assign_attributes(status: 'inactive')
      expect(protected_role.save(context: :status_transition)).to be(false)
      expect(protected_role.reload).to be_active
    end
  end

  it 'rolls back the status when the audit cannot be written' do
    allow_any_instance_of(SystemRoleStatusEvent).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
    expect { transition('inactive') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(role.reload).to be_active
    expect(role.status_events).to be_empty
  end

  it 'keeps audit records immutable' do
    transition('inactive')
    event = role.status_events.last
    expect { event.update!(reason: 'Rewritten') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(event.destroy).to be(false)
    expect(event.reload.reason).to eq('Reviewed access requirements')
  end
end
