# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection do
  subject(:connection) { described_class.allocate }

  let(:user) { build_stubbed(:user, id: 27) }

  before do
    allow(connection).to receive(:broadcast_presence)
  end

  describe '#connect' do
    before do
      allow(connection).to receive(:cookies).and_return(double(signed: { user_id: user.id }))
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
      allow(User).to receive(:track_online_connection)
    end

    it 'tracks a unique connection and broadcasts presence' do
      connection.connect

      expect(connection.current_user).to eq(user)
      expect(User).to have_received(:track_online_connection).with(user.id, an_instance_of(String))
      expect(connection).to have_received(:broadcast_presence)
    end

    it 'does not track unauthenticated connections' do
      allow(connection).to receive(:cookies).and_return(double(signed: {}))

      connection.connect

      expect(connection.current_user).to be_nil
      expect(User).not_to have_received(:track_online_connection)
    end

    it 'rejects an unknown signed user id' do
      allow(User).to receive(:find_by).with(id: user.id).and_return(nil)
      allow(connection).to receive(:reject_unauthorized_connection)
        .and_raise(ActionCable::Connection::Authorization::UnauthorizedError)

      expect { connection.connect }.to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
    end
  end

  describe '#disconnect' do
    it 'removes only the current connection, not other browser tabs' do
      connection.current_user = user
      connection.instance_variable_set(:@presence_token, 'socket-123')
      allow(User).to receive(:untrack_online_connection)

      connection.disconnect

      expect(User).to have_received(:untrack_online_connection).with(user.id, 'socket-123')
      expect(connection).to have_received(:broadcast_presence)
    end

    it 'does nothing without an identified user' do
      allow(User).to receive(:untrack_online_connection)

      connection.disconnect

      expect(User).not_to have_received(:untrack_online_connection)
    end
  end
end
