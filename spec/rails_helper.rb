# frozen_string_literal: true

require 'spec_helper'

ENCODING_FLAG = '#' unless defined?(ENCODING_FLAG)

# The docker images ship with RAILS_ENV=development and DATABASE_URL pointing
# at the development database, so the suite must force the test environment
# instead of relying on `||=`.
ENV['RAILS_ENV'] = 'test'

# Strip the container-level DATABASE_URL so the suite connects to the test
# database (config/database.yml + POSTGRES_DB_TEST) instead of truncating the
# development database (with the seeds) every time the specs run.
ENV.delete('DATABASE_URL')
require File.expand_path('../config/environment', __dir__)

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'capybara/rspec'
require 'shoulda/matchers'
# ─────────────────────────────
# AUTOLOAD SUPPORT FILES
# ─────────────────────────────
Rails.root.glob('spec/support/**/*.rb').sort.each { |f| require f }

# ─────────────────────────────
# RSPEC CONFIG GENERAL
# ─────────────────────────────
RSpec.configure do |config|
  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  config.filter_run_when_matching :focus

  config.order = :random

  config.profile_examples = 10

  # The app default locale is Spanish, but the suite expects English
  # assertions, so force it for deterministic spec runs.
  config.around(:each) do |example|
    I18n.with_locale(:en) { example.run }
  end

  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
