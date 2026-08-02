# frozen_string_literal: true

class Translate < ApplicationRecord
  validates :key, presence: true, uniqueness: { scope: :locale, conditions: -> { without_deleted } }
  validates :value, presence: true
  validates :locale, presence: true, inclusion: { in: %w[en es ko] }

  scope :by_locale, ->(locale) { where(locale: locale) }
  scope :by_key, ->(key) { where(key: key) }

  def self.find_by_key_and_locale(key, locale)
    by_locale(locale).by_key(key).first
  end

  def self.value_for(key, locale, default = nil)
    translation = find_by_key_and_locale(key, locale)
    translation&.value || default
  end
end

