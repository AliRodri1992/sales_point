require 'rails_helper'

RSpec.describe TerminalHelper, type: :helper do
  describe '#language_flag_path' do
    it 'resolves language flags through the local asset pipeline' do
      language = build(:language, flag_iso: 'mx')

      expect(helper.language_flag_path(language)).to include('/assets/flags/mx.svg')
      expect(helper.language_flag_path(language)).not_to include('flagcdn.com')
    end
  end
end
