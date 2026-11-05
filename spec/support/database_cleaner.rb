# frozen_string_literal: true

require 'database_cleaner/active_record'

DatabaseCleaner.allow_remote_database_url = true

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = RSpec.current_example.metadata[:concurrent_db] ? :truncation : :transaction
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  # Browser sessions must finish before their database records are cleaned.
  config.append_after(:each) do |example|
    # Stop browser heartbeats before removing the accounts they reference.
    ActionCable.server.restart if example.metadata[:js]
    DatabaseCleaner.clean
  end
end
