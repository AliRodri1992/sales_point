# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardHelper, type: :helper do
  describe '#javascript_dashboard_translations' do
    it 'returns a JSON string with all translation keys' do
      result = helper.javascript_dashboard_translations

      expect(result).to be_a(String)
      parsed = JSON.parse(result)
      expect(parsed).to be_a(Hash)
      expect(parsed['customize_dashboard']).to be_a(String)
      expect(parsed['save_changes']).to be_a(String)
      expect(parsed['saved_title']).to be_a(String)
      expect(parsed['saved_text']).to be_a(String)
      expect(parsed['save_error_title']).to be_a(String)
      expect(parsed['save_error_text']).to be_a(String)
    end

    it 'uses Rails internationalization for translations' do
      result = helper.javascript_dashboard_translations
      parsed = JSON.parse(result)

      expect(parsed['saved_title']).to eq(t('admin.dashboard.saved.title'))
      expect(parsed['saved_text']).to eq(t('admin.dashboard.saved.text'))
    end
  end
end
