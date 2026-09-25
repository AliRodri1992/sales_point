require 'rails_helper'

RSpec.describe BranchNotification, type: :model do
  let(:branch) { create(:branch) }
  let(:user) { create(:user) }

  it 'delivers a database notification with the branch and action' do
    expect do
      described_class.with(branch: branch, action: 'created').deliver(user)
    end.to change(Noticed::Notification, :count).by(1)

    notification = user.notifications.last

    expect(notification.type).to eq('BranchNotification')
    expect(notification.event.record).to eq(branch)
    expect(notification.event.params['action']).to eq('created')
  end
end
