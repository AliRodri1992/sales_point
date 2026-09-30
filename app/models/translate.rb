# frozen_string_literal: true

class Translate < ApplicationRecord
  belongs_to :language, optional: true
  belongs_to :translation_generation, optional: true

  validates :key, presence: true
  validates :value, presence: true
  validates :language, presence: true, if: -> { self.class.column_exists?(:language_id) }

  before_create :validate_uniqueness

  scope :by_language, ->(language) { where(language: language) if column_exists?(:language_id) }
  scope :by_locale, lambda { |locale|
    if column_exists?(:language_id)
      joins(:language).where(languages: { locale: locale })
    else
      where(locale: locale)
    end
  }
  scope :by_key, ->(key) { where(key: key) }
  scope :by_locale_code, ->(code) { by_locale(code) }

  def self.find_by_key_and_locale(key, locale)
    if column_exists?(:language_id)
      joins(:language)
        .where(key: key, languages: { locale: locale })
        .first
    else
      where(key: key, locale: locale).first
    end
  end

  def self.value_for(key, locale, default = nil)
    translation = find_by_key_and_locale(key, locale)
    translation&.value || default
  end

  def self.load_from_file(file_path, locale_code)
    return unless File.exist?(file_path)

    content = YAML.safe_load_file(file_path, aliases: false)
    locale_hash = content&.fetch(locale_code.to_s, nil)
    language = Language.find_by(code: locale_code)
    return unless locale_hash.is_a?(Hash) && language

    flatten_hash(locale_hash).each do |key, value|
      next if value.is_a?(Hash)

      translate = if column_exists?(:language_id)
                    find_or_initialize_by(key: key, language: language)
                  else
                    find_or_initialize_by(key: key, locale: locale_code)
                  end

      next if translate.persisted?

      translate.assign_attributes(
        value: value.to_s,
        translation_source: 'manual'
      )
      translate.save!
    end
  end

  def self.flatten_hash(hash, prefix = '')
    hash.each_with_object({}) do |(key, value), result|
      current_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        result.merge!(flatten_hash(value, current_key))
      else
        result[current_key] = value
      end
    end
  end

  def locale
    if self.class.column_exists?(:language_id)
      language&.locale || language&.code
    else
      self[:locale]
    end
  end

  def automatic?
    translation_source == 'automatic'
  end

  def protected?
    translation_source != 'automatic'
  end

  def stale?
    stale_at.present?
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
