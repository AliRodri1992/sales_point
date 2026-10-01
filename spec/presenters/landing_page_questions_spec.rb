# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LandingPage::Questions do
  describe '.all' do
    it 'resolves every FAQ translation for every supported locale' do
      expected_keys = %w[install offline migration commitment trial]

      %i[es en ko].each do |locale|
        I18n.with_locale(locale) do
          questions = described_class.all

          expect(questions.size).to eq(expected_keys.size)

          questions.each do |question|
            expect(question.question).not_to include('translation missing')
            expect(question.answer).not_to include('translation missing')
            expect(question.question).not_to include("\#{key}")
            expect(question.answer).not_to include("\#{key}")
          end
        end
      end
    end
  end
end
