require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Allow only the explicitly configured tunnel hostname.
  tunnel_host = ENV.fetch('TUNNEL_HOST', '').strip
  if tunnel_host.present?
    unless tunnel_host.match?(/\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/i)
      raise ArgumentError, 'TUNNEL_HOST must be a hostname without scheme, port or wildcard'
    end

    config.hosts << tunnel_host
  end

  # Do not expose detailed error reports when a tunnel is configured.
  config.consider_all_requests_local = tunnel_host.blank?

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { 'cache-control' => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Web and Sidekiq must share the i18n revision token across processes.
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    namespace: 'delta-pos:development:cache'
  }
  config.active_storage.service = :local

  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false

  config.action_mailer.delivery_method = :letter_opener_web
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  Rails.application.routes.default_url_options = {
    host: 'localhost',
    port: 3000,
    protocol: 'http'
  }
  config.action_mailer.default_url_options = {
    host: 'localhost',
    port: 3000,
    protocol: 'http'
  }
  config.action_mailer.asset_host = 'http://localhost:3000'

  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true
  config.active_job.verbose_enqueue_logs = true
  config.action_dispatch.verbose_redirect_logs = true
  config.assets.quiet = true

  # config.i18n.raise_on_missing_translations = true
  config.action_view.annotate_rendered_view_with_filenames = true
  config.action_controller.raise_on_missing_callback_actions = true
  # config.generators.apply_rubocop_autocorrect_after_generate!
end
