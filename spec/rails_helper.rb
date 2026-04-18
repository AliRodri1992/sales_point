# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'capybara/rspec'
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

  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
