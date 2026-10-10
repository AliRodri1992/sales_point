# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection do
  subject(:connection) { described_class.allocate }

  describe '#connect' do
    let(:user) { build_stubbed(:user, id: 27) }
    let(:online_users) { instance_double(Kredis::Types::Set, add: true) }

    before do
      allow(connection).to receive(:cookies).and_return(double(signed: { user_id: user.id }))
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
      allow(Kredis).to receive(:set).with(User::ONLINE_USERS_KEY).and_return(online_users)
      allow(online_users).to receive(:members).and_return([user.id.to_s])
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    end

    it 'identifies the user, records presence and broadcasts it' do
      allow(connection).to receive(:broadcast_presence)

      connection.connect

      expect(connection.current_user).to eq(user)
      expect(online_users).to have_received(:add).with(user.id)
      expect(connection).to have_received(:broadcast_presence)
    end

    it 'does not record presence when no signed user id is provided' do
      allow(connection).to receive(:cookies).and_return(double(signed: {}))

      connection.connect

      expect(connection.current_user).to be_nil
      expect(online_users).not_to have_received(:add)
    end

    it 'rejects an unknown signed user id' do
      allow(User).to receive(:find_by).with(id: user.id).and_return(nil)
      allow(connection).to receive(:reject_unauthorized_connection).and_raise(ActionCable::Connection::Authorization::UnauthorizedError)

      expect { connection.connect }.to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
    end
  end

  describe '#disconnect' do
    let(:user) { build_stubbed(:user, id: 27) }
    let(:online_users) { instance_double(Kredis::Types::Set, remove: true) }

    it 'removes an identified user from presence and broadcasts the change' do
      connection.current_user = user
      allow(connection).to receive(:online_users).and_return(online_users)
      allow(connection).to receive(:broadcast_presence)

      connection.disconnect

      expect(online_users).to have_received(:remove).with(user.id)
      expect(connection).to have_received(:broadcast_presence)
    end

    it 'does nothing when no user is identified' do
      allow(connection).to receive(:online_users)

      connection.disconnect

      expect(connection).not_to have_received(:online_users)
    end
  end
end
