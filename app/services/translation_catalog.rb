# frozen_string_literal: true

require 'digest'
require 'yaml'

class TranslationCatalog
  EXCLUDED_FILES = ['devise.security_extension.yml'].freeze

  def self.version_for(locale)
    payload = locale_files.filter_map do |file|
      next if excluded_file?(file)

      parsed = YAML.safe_load_file(file, aliases: false)
      locale_content = parsed&.fetch(locale.to_s, nil)
      [file.to_s, locale_content] if locale_content.is_a?(Hash)
    end

    Digest::SHA256.hexdigest(Marshal.dump(payload))
  end

  def initialize(locale)
    @locale = locale.to_s
  end

  def call
    merged = {}

    self.class.locale_files.each do |file|
      next if self.class.excluded_file?(file)

      document = YAML.safe_load_file(file, aliases: false)
      locale_hash = document&.fetch(@locale, nil)
      next unless locale_hash.is_a?(Hash)

      merged = deep_merge(merged, locale_hash)
    end

    flatten(merged)
  end

  def self.locale_files
    Rails.root.glob('config/locales/**/*.yml').sort
  end

  def self.excluded_file?(file)
    EXCLUDED_FILES.include?(File.basename(file))
  end

  private

  def flatten(hash, prefix = '', result = {})
    hash.each do |key, value|
      current_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"

      if value.is_a?(Hash)
        flatten(value, current_key, result)
      elsif value.is_a?(String)
        result[current_key] = value
      end
    end
    result
  end

  def deep_merge(left, right)
    left.merge(right) do |_key, existing, incoming|
      existing.is_a?(Hash) && incoming.is_a?(Hash) ? deep_merge(existing, incoming) : incoming
    end
  end
end
