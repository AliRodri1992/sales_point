# frozen_string_literal: true

require 'pg'
require 'zlib'

# Serializes RSpec runs that share the same PostgreSQL test database.
# Session locks are released automatically if the runner exits unexpectedly.
class TestDatabaseLock
  LOCK_NAMESPACE = 1_395_724_019
  DEFAULT_TIMEOUT_SECONDS = 30

  class Timeout < StandardError; end

  def initialize(environment: ENV, connector: PG.method(:connect), output: $stderr)
    @environment = environment
    @connector = connector
    @output = output
  end

  def synchronize
    acquire
    yield
  ensure
    release
  end

  def acquire
    raise 'The test database lock requires RAILS_ENV=test' unless @environment['RAILS_ENV'] == 'test'
    return if @connection && @owner_pid == Process.pid

    connection = @connector.call(**connection_options)
    configure_timeout(connection)
    wait_for_lock(connection)
    @connection = connection
    @owner_pid = Process.pid
  rescue PG::LockNotAvailable
    raise Timeout, "Test database #{database_name} is busy. Finish the other RSpec run and retry."
  ensure
    connection&.close if connection && !@connection.equal?(connection)
  end

  def release
    connection = @connection
    @connection = nil
    return unless connection && @owner_pid == Process.pid

    begin
      connection.exec_params('SELECT pg_advisory_unlock($1, $2)', lock_identifiers)
    ensure
      connection.close
    end
  end

  private

  def configure_timeout(connection)
    connection.exec_params('SELECT set_config($1, $2, false)', ['lock_timeout', "#{timeout_seconds}s"])
  end

  def wait_for_lock(connection)
    acquired = connection.exec_params('SELECT pg_try_advisory_lock($1, $2)', lock_identifiers).getvalue(0, 0)
    return if acquired == 't'

    @output.puts "[RSpec] Another test run is using #{database_name}; waiting up to #{timeout_seconds}s for the lock."
    connection.exec_params('SELECT pg_advisory_lock($1, $2)', lock_identifiers)
  end

  def connection_options
    options = {
      dbname: 'postgres',
      host: @environment.fetch('POSTGRES_HOST', 'db'),
      port: @environment.fetch('POSTGRES_PORT', '5432'),
      user: @environment.fetch('POSTGRES_USER', 'postgres'),
      connect_timeout: 5
    }
    options[:password] = @environment['POSTGRES_PASSWORD'] if @environment.key?('POSTGRES_PASSWORD')
    options
  end

  def database_name
    @environment.fetch('POSTGRES_DB_TEST', 'sale_point_test')
  end

  def timeout_seconds
    value = Integer(@environment.fetch('TEST_DB_LOCK_TIMEOUT_SECONDS', DEFAULT_TIMEOUT_SECONDS))
    raise ArgumentError, 'TEST_DB_LOCK_TIMEOUT_SECONDS must be positive' unless value.positive?

    value
  end

  def lock_identifiers
    id = Zlib.crc32(database_name)
    id -= 2**32 if id >= 2**31
    [LOCK_NAMESPACE, id]
  end
end
