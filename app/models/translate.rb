# frozen_string_literal: true

class Translate < ApplicationRecord
  belongs_to :language, optional: true

  validates :key, presence: true, uniqueness: { scope: :language_id, conditions: -> { without_deleted } }
  validates :value, presence: true
  validates :language, presence: true

  scope :by_language, ->(language) { where(language: language) }
  scope :by_locale, ->(locale) do
    joins(:language).where(languages: { code: locale })
  end
  scope :by_key, ->(key) { where(key: key) }

  # Backward compatibility with locale string
  scope :by_locale_code, ->(code) { by_locale(code) }

  def self.find_by_key_and_locale(key, locale)
    joins(:language)
      .where(key: key, languages: { code: locale })
      .first
  end

  def self.value_for(key, locale, default = nil)
    translation = find_by_key_and_locale(key, locale)
    translation&.value || default
  end

  # Load translations from a YAML file for a specific locale
  def self.load_from_file(file_path, locale_code)
    return unless File.exist?(file_path)

    content = YAML.safe_load(File.read(file_path))
    locale_hash = content[locale_code.to_s]

    return unless locale_hash

    language = Language.find_by(code: locale_code)
    return unless language

    flatten_hash(locale_hash, '').each do |key, value|
      next if value.is_a?(Hash)

      translate = find_or_create_by(key: key, language: language)
      translate.update(value: value.to_s)
    end
  end

  # Flatten nested hash into dot-notation keys
  def self.flatten_hash(hash, prefix = '')
    result = {}
    hash.each do |key, value|
      current_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        result.merge!(flatten_hash(value, current_key))
      else
        result[current_key] = value
      end
    end
    result
  end

  # Return locale code from associated language
  def locale
    language&.code
  end
end

