# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRoleNotification, type: :model do
  let(:system_role) { create(:system_role, name: 'Cashier', code: 'cashier') }
  let(:user) { create(:user) }

  it 'delivers a database notification with the role and actor' do
    expect do
      described_class.with(
        action: 'created',
        record: system_role,
        user: user
      ).deliver(user, enqueue_job: false)
    end.to change(Noticed::Notification, :count).by(1)

    notification = user.notifications.last
    expect(notification.type).to eq('SystemRoleNotification::Notification')
    expect(notification.event.record).to eq(system_role)
    expect(notification.event.params[:action]).to eq('created')
    expect(notification.event.params[:user]).to eq(user)
  end

  it 'provides a descriptive translated notification message' do
    described_class.with(
      action: 'updated',
      record: system_role,
      user: user
    ).deliver(user, enqueue_job: false)

    expect(user.notifications.last.event.message).to eq(
      I18n.t('admin.shared.notifications.system_role.updated', name: system_role.name)
    )
  end

  it 'keeps the record available once the role is deprecated' do
    described_class.with(
      action: 'updated',
      record: system_role,
      user: user
    ).deliver(user, enqueue_job: false)

    notification = user.notifications.last
    system_role.update!(deleted_at: Time.current, status: :deprecated)

    expect(notification.event.record).to eq(system_role)
  end
end
