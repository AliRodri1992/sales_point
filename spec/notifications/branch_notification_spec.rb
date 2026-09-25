require 'rails_helper'

RSpec.describe BranchNotification, type: :model do
  let(:branch) { create(:branch) }
  let(:user) { create(:user) }

  it 'delivers a database notification with the branch, action and user' do
    expect do
      described_class
        .with(action: 'created', record: branch, user: user)
        .deliver(user, enqueue_job: false)
    end.to change(Noticed::Notification, :count).by(1)

    notification = user.notifications.last

    expect(notification.type).to eq('BranchNotification')
    expect(notification.event.record).to eq(branch)
    expect(notification.event.params['action']).to eq('created')
    expect(notification.event.params['user']).to eq(user)
  end

  it 'provides the notification message' do
    notification = described_class.with(
      action: 'updated',
      record: branch,
      user: user
    ).to_notification(user)

    expect(notification.message).to eq("Se actualizó la sucursal '#{branch.name}'")
  end
end
