require 'rails_helper'

RSpec.describe BranchNotification, type: :model do
  let(:branch) { create(:branch) }
  let(:user) { create(:user) }

  it 'delivers a database notification with the branch and actor' do
    expect do
      described_class.with(
        action: 'destroyed',
        record: branch,
        user: user,
        user_name: user.display_name
      ).deliver(user, enqueue_job: false)
    end.to change(Noticed::Notification, :count).by(1)

    notification = user.notifications.last
    expect(notification.type).to eq('BranchNotification')
    expect(notification.event.record).to eq(branch)
    expect(notification.event.params['action']).to eq('destroyed')
    expect(notification.event.params['user_name']).to eq(user.display_name)
  end

  it 'provides a descriptive translated notification message' do
    notification = described_class.with(
      action: 'destroyed',
      record: branch,
      user: user,
      user_name: user.display_name
    ).to_notification(user)

    expect(notification.message).to eq(
      "Se eliminó la sucursal '#{branch.name}' por #{user.display_name}"
    )
  end
end
