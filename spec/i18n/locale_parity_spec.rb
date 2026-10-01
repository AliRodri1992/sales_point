# frozen_string_literal: true

require 'rails_helper'

LOCALES = %w[es en ko].freeze
BASE_LOCALE = 'es'

RSpec.describe 'Locale coverage', type: :model do
  def flatten_keys(value, prefix = nil, result = [])
    return result unless value.is_a?(Hash)

    value.each do |key, child|
      path = [prefix, key.to_s].compact.join('.')
      if child.is_a?(Hash)
        flatten_keys(child, path, result)
      else
        result << path
      end
    end

    result
  end

  def locale_data(locale)
    YAML.safe_load_file(
      Rails.root.join('config', 'locales', "#{locale}.yml"),
      aliases: true
    ).fetch(locale)
  end

  it 'loads every locale and keeps all Spanish translation keys available' do
    base_keys = flatten_keys(locale_data(BASE_LOCALE)).sort

    LOCALES.drop(1).each do |locale|
      locale_keys = flatten_keys(locale_data(locale))
      missing = base_keys - locale_keys

      expect(missing).to be_empty,
                         "Missing #{locale} translations: #{missing.join(', ')}"
    end
  end

  it 'does not contain the retired NEXO POS branding in locale files' do
    LOCALES.each do |locale|
      path = Rails.root.join('config', 'locales', "#{locale}.yml")
      expect(File.read(path)).not_to match(/NEXO\s*POS/i)
    end
  end
end
