# frozen_string_literal: true

class Translate < ApplicationRecord
  CACHE_KEY = 'delta_pos:i18n:translations:revision'

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
    if @checked_at.nil? || now - @checked_at >= 1
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

  def self.load_from_file(file_path, locale_code, overwrite: false, dry_run: false)
    return unless File.exist?(file_path)

    content = YAML.safe_load_file(file_path)
    locale_hash = content[locale_code.to_s]

    return unless locale_hash

    language = Language.find_by(code: locale_code)
    return unless language

    options = { overwrite:, dry_run: }
    flatten_hash(locale_hash, '').each do |key, value|
      import_translation_entry(key, value, language, locale_code, options)
    end
  end

  def self.import_translation_entry(key, value, language, locale_code, options)
    return if options[:dry_run] || value.blank?

    lookup = column_exists?(:language_id) ? { key:, language: } : { key:, locale: locale_code }
    translation = find_or_initialize_by(**lookup)
    source = value.to_s

    changes = { yaml_value: source }
    changes[:value] = source if sync_yaml_translation?(translation, options)
    return if translation.persisted? && changes.all? { |field, value| translation.public_send(field) == value }

    translation.update!(changes)
  end
  private_class_method :import_translation_entry

  def self.sync_yaml_translation?(translation, options)
    translation.new_record? || options[:overwrite] ||
      (!translation.yaml_value.nil? && translation.value == translation.yaml_value)
  end
  private_class_method :sync_yaml_translation?
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
    return unless translation_duplicates.exists?

    kind = self.class.column_exists?(:language_id) ? 'language' : 'locale'
    errors.add(:key, "already exists for this #{kind}")
  end

  def translation_duplicates
    relation = if self.class.column_exists?(:language_id)
                 Translate.where(key: key, language_id: language_id, deleted_at: nil)
               else
                 Translate.where(key: key, locale: self[:locale])
               end
    persisted? ? relation.where.not(id: id) : relation
  end
end
