# frozen_string_literal: true

# Custom I18n backend that loads translations from database
module I18n
  module Backend
    class DatabaseBackend < Simple
      def initialize
        super
        load_all_from_database
      end

      def load_all_from_database
        return unless defined?(Translate)

        Translate.all.each do |translate|
          store_translation(translate.locale.to_sym, translate.key, translate.value)
        end
      end

      private

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

# Fallback to file-based translations if database is not available
begin
  if defined?(ActiveRecord)
    if ActiveRecord::Base.connection.table_exists?('translates')
      I18n.backend = I18n::Backend::DatabaseBackend.new
    end
  end
rescue StandardError
  # Database connection failed, use default backend
end
