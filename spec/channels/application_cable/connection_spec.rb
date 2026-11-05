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
      signed = { user_id: { 'id' => user.id, 'issued_at' => 123.0 } }
      allow(connection).to receive(:cookies).and_return(double(signed:))
      allow(User).to receive(:find_by).with(id: user.id).and_return(user)
      allow(user).to receive(:active_for_authentication?).and_return(true)
      allow(User).to receive(:track_online_connection)
    end

    it 'tracks a unique connection and broadcasts presence' do
      connection.connect

      expect(connection.current_user).to eq(user)
      expect(User).to have_received(:track_online_connection).with(user.id, an_instance_of(String))
      expect(connection).to have_received(:broadcast_presence)
    end

    it 'rejects a signed cookie created before session revocation' do
      allow(user).to receive(:session_revoked_at).and_return(Time.zone.at(124))
      allow(connection).to receive(:reject_unauthorized_connection)
        .and_raise(ActionCable::Connection::Authorization::UnauthorizedError)

      expect { connection.connect }.to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
      expect(User).not_to have_received(:track_online_connection)
    end

    it 'rejects unauthenticated connections without tracking presence' do
      allow(connection).to receive(:cookies).and_return(double(signed: {}))
      allow(connection).to receive(:reject_unauthorized_connection)
        .and_raise(ActionCable::Connection::Authorization::UnauthorizedError)

      expect { connection.connect }.to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
      expect(User).not_to have_received(:track_online_connection)
    end

    it 'rejects an unknown signed user id' do
      allow(User).to receive(:find_by).with(id: user.id).and_return(nil)
      allow(connection).to receive(:reject_unauthorized_connection)
        .and_raise(ActionCable::Connection::Authorization::UnauthorizedError)

      expect { connection.connect }.to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
    end

    it 'closes an existing socket when the account is disabled' do
      connection.connect
      allow(user).to receive(:reload).and_return(user)
      allow(user).to receive(:active_for_authentication?).and_return(false)
      expect(connection).to receive(:close).with(reason: 'Access revoked')
      connection.beat
      expect(User).to have_received(:track_online_connection).once
    end

    it 'closes an existing socket after its session is revoked' do
      connection.connect
      allow(user).to receive(:reload).and_return(user)
      allow(user).to receive(:session_revoked_at).and_return(Time.zone.at(124))
      expect(connection).to receive(:close).with(reason: 'Access revoked')
      connection.beat
      expect(User).to have_received(:track_online_connection).once
    end

    it 'refreshes presence for a session issued after the revocation timestamp' do
      allow(user).to receive(:session_revoked_at).and_return(Time.zone.at(122))
      connection.connect
      allow(user).to receive(:reload).and_return(user)
      allow(connection).to receive(:transmit)
      connection.beat
      expect(User).to have_received(:track_online_connection).twice
    end
  end

  it 'ignores heartbeat messages before authentication finishes' do
    expect(User).not_to receive(:track_online_connection)
    connection.beat
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

    it 'handles disconnects before a presence token is registered' do
      connection.current_user = user
      expect(User).not_to receive(:untrack_online_connection)
      connection.disconnect
    end
  end
end
