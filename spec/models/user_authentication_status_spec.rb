# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User account access status', type: :model do
  it 'only allows active, non-deleted accounts to authenticate with Devise' do
    user = create(:user, status: :active)
    expect(user.active_for_authentication?).to be(true)

    user.update!(status: :suspended)
    expect(user.active_for_authentication?).to be(false)

    user.update!(status: :blocked)
    expect(user.active_for_authentication?).to be(false)

    user.update!(status: :active, deleted_at: Time.current)
    expect(user.active_for_authentication?).to be(false)
  end
end
