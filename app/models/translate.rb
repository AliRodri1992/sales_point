# frozen_string_literal: true

class Translate < ApplicationRecord
  belongs_to :language, optional: true

  validates :key, presence: true
  validates :value, presence: true

  validates :language, presence: true, if: -> { ActiveRecord::Base.connection.column_exists?(:translates, :language_id) }

  before_create :validate_uniqueness

  scope :by_language, ->(language) { where(language: language) if column_exists?(:language_id) }
  scope :by_locale, lambda { |locale|
    if column_exists?(:language_id)
      joins(:language).where(languages: { code: locale })
    else
      where(locale: locale)
    end
  }
  scope :by_key, ->(key) { where(key: key) }
  scope :by_locale_code, ->(code) { by_locale(code) }

  def self.find_translation(key, locale)
    if column_exists?(:language_id)
      language = Language.find_by(code: locale)
      language && where(key: key, language: language).first
    else
      where(key: key, locale: locale).first
    end
  end

  def self.value_for(key, locale, default = nil)
    find_translation(key, locale)&.value || default
  end

  def self.load_from_file(file_path, locale_code)
    return unless File.exist?(file_path)

    content = YAML.safe_load_file(file_path)
    locale_hash = content[locale_code.to_s]

    return unless locale_hash

    language = Language.find_by(code: locale_code)
    return unless language

    flatten_hash(locale_hash, '').each do |key, value|
      next if value.is_a?(Hash)

      translate = if column_exists?(:language_id)
                    find_or_create_by!(key: key, language: language)
                  else
                    find_or_create_by!(key: key, locale: locale_code)
                  end
      translate.update!(value: value.to_s)
    end
  end

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

  def locale
    if self.class.column_exists?(:language_id)
      language && language[:code]
    else
      self[:locale]
    end
  end

  def self.column_exists?(column_name)
    ActiveRecord::Base.connection.column_exists?(:translates, column_name)
  end

  private

  def validate_uniqueness
    if self.class.column_exists?(:language_id)
      if Translate.where(key: key, language_id: language_id).exists?(deleted_at: nil)
        errors.add(:key, 'already exists for this language')
      end
    elsif Translate.exists?(key: key, locale: self[:locale])
      errors.add(:key, 'already exists for this locale')
    end
  end
end
