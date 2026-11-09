# frozen_string_literal: true

# PostgreSQL overrides take precedence; YAML remains the safe fallback.
# Keep the database backend installed even before the first db:migrate.
require 'i18n/backend/chain'

module I18n
  module Backend
    class DatabaseBackend < Simple
      def initialize
        super
        @reload_mutex = Mutex.new
        @translations_loaded = false
      end

      def lookup(locale, key, scope = [], options = {})
        refresh_translations
        super
      end

      private

      def refresh_translations
        return unless defined?(Translate)

        revision = Translate.cache_revision
        return if @translations_loaded && @loaded_revision == revision
        return unless translation_tables_exist?

        @reload_mutex.synchronize do
          return if @translations_loaded && @loaded_revision == revision

          fresh = {}
          Translate.includes(:language).find_each do |entry|
            language_code = entry.language&.code
            next unless language_code

            parts = entry.key.to_s.split('.')
            next if parts.empty?

            node = (fresh[language_code.to_sym] ||= {})
            parts[0..-2].each { |part| node = (node[part.to_sym] ||= {}) }
            node[parts.last.to_sym] = entry.value
          end

          # Only replace the published snapshot after a successful full load.
          @translations = fresh
          @initialized = true
          @translations_loaded = true
          @loaded_revision = revision
        end
      rescue StandardError => e
        Rails.logger.warn("Failed to refresh database translations: #{e.class}: #{e.message}")
      end

      def translation_tables_exist?
        connection = ActiveRecord::Base.connection
        connection.data_source_exists?('translates') &&
          connection.data_source_exists?('languages') &&
          connection.column_exists?(:translates, :language_id)
      end
    end
  end
end

begin
  file_backend = I18n::Backend::Simple.new
  file_backend.load_translations(Dir[Rails.root.join('config', 'locales', '**', '*.yml')])

  # This backend retries loading when the schema first becomes available and
  # automatically reloads after translation/language changes.
  I18n.backend = I18n::Backend::Chain.new(I18n::Backend::DatabaseBackend.new, file_backend)
  Rails.logger.debug('Using chained I18n backend (database overrides, YAML fallback)')
rescue StandardError => e
  Rails.logger.warn("Failed to configure I18n backend: #{e.class}: #{e.message}")
end
