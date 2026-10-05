# frozen_string_literal: true

RSpec.describe Translate, type: :model do
  describe '.flatten_hash' do
    it 'flattens nested translation values' do
      expect(described_class.flatten_hash({ dashboard: { title: 'Title' }, action: 'Save' }))
        .to eq('dashboard.title' => 'Title', 'action' => 'Save')
    end
  end

  describe '.value_for' do
    let(:language) { create(:language, code: 'en') }

    before do
      described_class.create!(language:, key: 'welcome.title', value: 'Welcome')
    end

    it 'returns the stored value for a locale' do
      expect(described_class.value_for('welcome.title', 'en')).to eq('Welcome')
    end

    it 'returns the default when the translation does not exist' do
      expect(described_class.value_for('missing.key', 'en', 'Fallback')).to eq('Fallback')
    end
  end

  describe '#locale' do
    it 'returns the associated language code' do
      language = create(:language, code: 'es')
      translate = described_class.new(language:)

      expect(translate.locale).to eq('es')
    end
  end

  describe 'uniqueness' do
    it 'rejects duplicate keys for the same language' do
      language = create(:language, code: 'en')
      described_class.create!(language:, key: 'duplicate.key', value: 'Original')

      duplicate = described_class.new(language:, key: 'duplicate.key', value: 'Duplicate')
      expect(duplicate.save).to be(false)
      expect(duplicate.errors[:key]).to include('already exists for this language')
    end
  end
end
