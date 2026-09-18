# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.hour.to_i}" }
  config.active_storage.service = :local

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :sidekiq

  config.action_mailer.perform_caching = false
  config.action_mailer.perform_deliveries = ENV.fetch("MAILER_DELIVERY", "false") == "true"
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "staging.example.com"),
    protocol: ENV.fetch("APP_PROTOCOL", "https")
  }

  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      domain: ENV.fetch("SMTP_DOMAIN", ENV.fetch("APP_HOST", "staging.example.com")),
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true"
    }.compact
  end

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    {
      time: event.time,
      params: event.payload[:params].except("controller", "action"),
      ip: event.payload[:remote_ip]
    }
  end

  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.hosts << ENV["APP_HOST"] if ENV["APP_HOST"].present?
  config.action_controller.raise_on_missing_callback_actions = true
end
