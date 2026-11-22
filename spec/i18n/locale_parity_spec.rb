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
    Rails.root.glob('config/locales/**/*.{yml,yaml}').each_with_object({}) do |path, data|
      parsed = YAML.safe_load_file(path, aliases: true)
      locale_data = parsed.fetch(locale, nil)
      data.deep_merge!(locale_data) if locale_data.is_a?(Hash)
    end
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

  %i[es en ko].each do |locale|
    it "resolves application and framework translations in #{locale} without fallback" do
      keys = %w[
        admin.languages.created admin.languages.updated admin.languages.destroyed
        admin.products.destroy_failed admin.products.index.not_found
        admin.supplier_details.address_form.summary_heading
        admin.supplier_dossier.contact_cards.additional_phones admin.supplier_dossier.contact_cards.more_details
        admin.procurement.yes admin.units_of_measure.filters.yes admin.units_of_measure.filters.no
        admin.suppliers.index.advanced.options.yes admin.suppliers.index.advanced.options.no
        countries.NO landing.dashboard.sale
        admin.dashboard.page_header.new_sale admin.dashboard.page_header.save_changes
      ]
      keys.each do |key|
        value = I18n.t(key, locale:, raise: true, fallback: false)
        expect(value).to be_a(String).and be_present
        expect(value).not_to match(/translation[ _]missing/i)
      end
      days = I18n.t('date.day_names', locale:, raise: true, fallback: false)
      expect(days).to be_an(Array).and have_attributes(size: 7)
    end
  end
end
