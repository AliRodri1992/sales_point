# frozen_string_literal: true

# Custom I18n backend that loads translations from both files and database
# This backend chains file translations with database translations

require 'i18n/backend/chain'

module I18n
  module Backend
    class DatabaseBackend < Simple
      def initialize
        super
        @translations_loaded = false
      end

      def load_all_from_database
        return if @translations_loaded
        return unless defined?(Translate) && table_exists?

        begin
          Translate.includes(:language).each do |translate|
            locale = translate.language&.locale || translate.language&.code
            next unless locale

            store_translation(locale.to_sym, translate.key, translate.value)
          end
          @translations_loaded = true
        rescue StandardError => e
          Rails.logger.warn("Failed to load translations from database: #{e.message}")
        end
      end

      def reload!
        @translations_loaded = false
        @translations = {}
      end

      def lookup(locale, key, scope = [], options = {})
        load_all_from_database unless @translations_loaded
        super
      end

      private

      def table_exists?
        return false unless defined?(ActiveRecord)

        begin
          ActiveRecord::Base.connection.table_exists?('translates')
        rescue StandardError
          false
        end
      end

      def store_translation(locale, key, value)
        key_parts = key.split('.')
        translations = (@translations ||= {})[locale] ||= {}

        key_parts[0..-2].each do |part|
          translations = translations[part.to_sym] ||= {}
        end

        translations[key_parts.last.to_sym] = value
      end
    end
  end
end

# Chain the file backend with the database backend
# File backend first, then database backend as fallback
begin
  file_backend = I18n::Backend::Simple.new
  file_backend.load_translations(Dir[Rails.root.join('config', 'locales', '**', '*.yml')])

  if defined?(ActiveRecord) && ActiveRecord::Base.connection.table_exists?('translates')
    db_backend = I18n::Backend::DatabaseBackend.new
    I18n.backend = I18n::Backend::Chain.new(file_backend, db_backend)
    Rails.logger.debug("Using chained I18n backend (file + database)")
  else
    I18n.backend = file_backend
    Rails.logger.debug("Using I18n file backend")
  end
rescue StandardError => e
  Rails.logger.warn("Failed to configure I18n backend: #{e.message}")
  # Keep default backend if anything fails
end