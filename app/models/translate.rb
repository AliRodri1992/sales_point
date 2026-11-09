# frozen_string_literal: true

class Translate < ApplicationRecord
  CACHE_KEY = 'delta_pos:i18n:translations:revision'.freeze

  belongs_to :language, optional: true

  after_commit :invalidate_translation_backend

  validates :key, presence: true, length: { maximum: 255 }
  validates :value, presence: true

  validates :language, presence: true, if: -> { ActiveRecord::Base.connection.column_exists?(:translates, :language_id) }

  validate :validate_uniqueness

  # Shared cache token + local generation: works with Redis/SolidCache and
  # immediately invalidates the current process even with a null cache in tests.
  def self.cache_revision
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if !defined?(@checked_at) || now - @checked_at >= 1
      @shared_revision = Rails.cache.read(CACHE_KEY)
      @checked_at = now
    end

    [@local_revision || 0, @shared_revision]
  end

  def self.invalidate_cache!
    @local_revision = (@local_revision || 0) + 1
    @shared_revision = SecureRandom.hex(16)
    Rails.cache.write(CACHE_KEY, @shared_revision)
    @checked_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  scope :by_language, ->(language) { where(language: language) if Translate.column_exists?(:language_id) }
  scope :by_locale, ->(locale) { by_locale_code(locale) }
  scope :by_key, ->(key) { where(key: key) }
  scope :by_locale_code, ->(code) { by_locale_code_query(code) }

  def self.by_locale_code_query(locale)
    if column_exists?(:language_id)
      joins(:language).where(languages: { code: locale })
    else
      where(locale: locale)
    end
  end

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
                    find_or_initialize_by(key: key, language: language)
                  else
                    find_or_initialize_by(key: key, locale: locale_code)
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

  def invalidate_translation_backend
    self.class.invalidate_cache!
  end

  def validate_uniqueness
    if self.class.column_exists?(:language_id)
      duplicates = Translate.where(key: key, language_id: language_id, deleted_at: nil)
      duplicates = duplicates.where.not(id: id) if persisted?
      errors.add(:key, 'already exists for this language') if duplicates.exists?
    else
      duplicates = Translate.where(key: key, locale: self[:locale])
      duplicates = duplicates.where.not(id: id) if persisted?
      errors.add(:key, 'already exists for this locale') if duplicates.exists?
    end
  end
end
