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

  describe '#current_terminal_language' do
    it 'uses the selected session language' do
      allow(helper).to receive(:session).and_return(language: 'ko')

      expect(helper.current_terminal_language).to eq('ko')
    end

    it 'defaults to English when no language is selected' do
      allow(helper).to receive(:session).and_return({})

      expect(helper.current_terminal_language).to eq('en')
    end
  end

  describe '#current_language' do
    let(:language) { build(:language) }

    it 'looks up the language selected by session id' do
      allow(helper).to receive(:session).and_return(language_id: language.id)
      allow(Language).to receive(:find_by).with(id: language.id).and_return(language)

      expect(helper.current_language).to eq(language)
    end

    it 'falls back to the first available language' do
      allow(helper).to receive(:session).and_return({})
      allow(Language).to receive(:find_by).with(id: nil).and_return(nil)
      allow(Language).to receive(:available).and_return([language])

      expect(helper.current_language).to eq(language)
    end
  end

  describe '#current_terminal_theme' do
    it 'uses the selected terminal theme cookie' do
      allow(helper).to receive(:cookies).and_return(terminal_theme: 'dark')

      expect(helper.current_terminal_theme).to eq('dark')
    end

    it 'uses the default theme when no cookie is set' do
      allow(helper).to receive(:cookies).and_return({})

      expect(helper.current_terminal_theme).to eq(Theme::DEFAULT)
    end
  end

  describe '#terminal_theme_selected?' do
    it 'returns true when the selection cookie is present' do
      allow(helper).to receive(:cookies).and_return(terminal_theme_selected: '1')

      expect(helper.terminal_theme_selected?).to be(true)
    end

    it 'returns false when the selection cookie is absent' do
      allow(helper).to receive(:cookies).and_return({})

      expect(helper.terminal_theme_selected?).to be(false)
    end
  end

  describe '#terminal_themes and #terminal_languages' do
    it 'returns all themes and available languages' do
      themes = [build(:theme)]
      languages = [build(:language)]
      allow(Theme).to receive(:all).and_return(themes)
      allow(Language).to receive(:available).and_return(languages)

      expect(helper.terminal_themes).to eq(themes)
      expect(helper.terminal_languages).to eq(languages)
    end
  end

  describe '#current_language_flag' do
    it 'returns the current language' do
      language = build(:language)
      allow(helper).to receive(:current_language).and_return(language)

      expect(helper.current_language_flag).to eq(language)
    end
  end

end
