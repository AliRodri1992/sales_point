require 'rails_helper'

RSpec.describe TranslationGeneration, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:language) }
    it { is_expected.to belong_to(:source_language).class_name('Language').optional }
    it { is_expected.to belong_to(:actor).class_name('User').optional }
    it { is_expected.to have_many(:translates).dependent(:nullify) }
  end

  describe '.enqueue_for!' do
    it 'reuses an active generation for the same language and catalog' do
      language = create(:language, code: 'fr', locale: 'fr')
      allow(TranslationCatalog).to receive(:version_for).and_return('same-version')

      first = described_class.enqueue_for!(language)
      second = described_class.enqueue_for!(language)

      expect(second.id).to eq(first.id)
    end
  end
end
