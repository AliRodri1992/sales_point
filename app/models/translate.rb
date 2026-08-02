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

  # Return locale code from associated language
  def locale
    language&.code
  end
end

