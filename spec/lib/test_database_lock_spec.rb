# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe TestDatabaseLock do
  let(:environment) do
    {
      'RAILS_ENV' => 'test',
      'POSTGRES_DB_TEST' => 'sale_point_test',
      'POSTGRES_HOST' => 'db',
      'POSTGRES_PORT' => '5432',
      'POSTGRES_USER' => 'postgres',
      'POSTGRES_PASSWORD' => 'postgres',
      'TEST_DB_LOCK_TIMEOUT_SECONDS' => '2'
    }
  end
  let(:connection) { instance_double(PG::Connection) }
  let(:result) { instance_double(PG::Result, getvalue: 't') }
  let(:connector) { instance_double(Method) }
  let(:output) { StringIO.new }
  let(:guard) { described_class.new(environment: environment, connector: connector, output: output) }

  before do
    allow(connector).to receive(:call).and_return(connection)
    allow(connection).to receive(:exec_params).and_return(result)
    allow(connection).to receive(:close)
  end

  it 'holds the session lock while the guarded command executes and releases it afterward' do
    expect(connection).to receive(:exec_params).with('SELECT pg_advisory_unlock($1, $2)', anything)
    guard.synchronize { expect(connection).not_to have_received(:close) }
    expect(connection).to have_received(:close)
  end

  it 'waits for another RSpec process without truncating the database' do
    allow(result).to receive(:getvalue).and_return('f')
    expect(connection).to receive(:exec_params).with('SELECT pg_advisory_lock($1, $2)', anything)
    guard.synchronize { expect(output.string).to include('waiting up to 2s') }
  end

  it 'raises a clear error and closes the connection when the wait expires' do
    allow(result).to receive(:getvalue).and_return('f')
    allow(connection).to receive(:exec_params).with('SELECT pg_advisory_lock($1, $2)', anything)
                                               .and_raise(PG::LockNotAvailable)

    expect { guard.synchronize { raise 'should not execute' } }
      .to raise_error(described_class::Timeout, /Finish the other RSpec run/)
    expect(connection).to have_received(:close)
  end

  it 'refuses to lock a development or production environment' do
    environment['RAILS_ENV'] = 'development'
    expect { guard.acquire }.to raise_error(/requires RAILS_ENV=test/)
    expect(connector).not_to have_received(:call)
  end

  it 'uses a different advisory key for each test database' do
    original_key = guard.send(:lock_identifiers)
    environment['POSTGRES_DB_TEST'] = 'another_test_db'
    expect(guard.send(:lock_identifiers)).not_to eq(original_key)
  end
end
