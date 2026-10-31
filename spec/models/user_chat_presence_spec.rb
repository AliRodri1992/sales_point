# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, 'chat presence' do
  let(:redis) { instance_double(Redis) }

  before do
    allow(described_class).to receive(:presence_redis).and_return(redis)
  end

  it 'stores a separate heartbeat for each browser connection' do
    allow(redis).to receive(:zadd)
    freeze_time do
      described_class.track_online_connection(27, 'tab-a')
      described_class.track_online_connection(27, 'tab-b')

      expect(redis).to have_received(:zadd)
        .with(described_class::ONLINE_USERS_KEY, Time.current.to_i, '27:tab-a')
      expect(redis).to have_received(:zadd)
        .with(described_class::ONLINE_USERS_KEY, Time.current.to_i, '27:tab-b')
    end
  end

  it 'deduplicates online users and prunes expired connections' do
    allow(redis).to receive(:zremrangebyscore)
    allow(redis).to receive(:zrange).and_return(%w[27:tab-a 27:tab-b 31:tab-c])

    freeze_time do
      expect(described_class.online_user_ids).to eq([27, 31])
      expect(redis).to have_received(:zremrangebyscore)
        .with(described_class::ONLINE_USERS_KEY, '-inf', Time.current.to_i - 60)
    end
  end

  it 'removes only the disconnected socket token' do
    allow(redis).to receive(:zrem)

    described_class.untrack_online_connection(27, 'tab-a')

    expect(redis).to have_received(:zrem).with(described_class::ONLINE_USERS_KEY, '27:tab-a')
  end
end
