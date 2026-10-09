require 'rails_helper'

RSpec.describe TerminalHelper, type: :helper do
  describe '#language_flag_path' do
    it 'resolves available language flags through the local asset pipeline' do
      language = build(:language, flag_iso: 'mx')

      expect(helper.language_flag_path(language)).to match(%r{/assets/flags/mx-[a-f0-9]+\.svg})
      expect(helper.language_flag_path(language)).not_to include('flagcdn.com')
    end

    it 'falls back to FlagCDN when a local flag asset is unavailable' do
      language = build(:language, flag_iso: 'tl')

      expect(helper.language_flag_path(language)).to eq('https://flagcdn.com/64x48/tl.png')
    end
  end
end
