# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Translate, type: :model do
  describe '.flatten_hash' do
    it 'flattens nested and scalar values' do
      expect(
        described_class.flatten_hash(dashboard: { title: 'Title' }, action: 'Save')
      ).to eq('dashboard.title' => 'Title', 'action' => 'Save')
    end

    it 'uses an existing prefix' do
      expect(described_class.flatten_hash({ title: 'Title' }, 'dashboard'))
        .to eq('dashboard.title' => 'Title')
    end
  end

  describe '.by_language' do
    it 'filters by language' do
      language = create(:language, code: 'en')
      translation = create(:translate, language:)

      expect(described_class.by_language(language)).to include(translation)
    end

    it 'returns the unscoped relation for the legacy schema' do
      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)

      expect(described_class.by_language('en')).to eq(described_class.all)
    end
  end

  describe '.by_locale' do
    it 'filters by associated language' do
      language = create(:language, code: 'en')
      translation = create(:translate, language:)

      expect(described_class.by_locale('en')).to include(translation)
    end

    it 'uses the legacy locale column' do
      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)
      expect(described_class).to receive(:where).with(locale: 'en')

      described_class.by_locale_code_query('en')
    end
  end

  describe '.find_translation' do
    it 'finds a translation' do
      language = create(:language, code: 'en')
      translation = create(:translate, language:, key: 'welcome.title')

      expect(described_class.find_translation('welcome.title', 'en')).to eq(translation)
    end

    it 'returns nil when language is absent' do
      expect(described_class.find_translation('welcome.title', 'fr')).to be_nil
    end

    it 'uses the legacy locale column' do
      relation = instance_double(ActiveRecord::Relation)
      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)
      allow(described_class).to receive(:where).with(key: 'welcome.title', locale: 'en').and_return(relation)
      allow(relation).to receive(:first).and_return(:translation)

      expect(described_class.find_translation('welcome.title', 'en')).to eq(:translation)
    end
  end

  describe '.value_for' do
    it 'returns stored value' do
      language = create(:language, code: 'en')
      create(:translate, language:, key: 'welcome.title', value: 'Welcome')

      expect(described_class.value_for('welcome.title', 'en')).to eq('Welcome')
    end

    it 'returns default when missing' do
      expect(described_class.value_for('missing.key', 'en', 'Fallback')).to eq('Fallback')
    end
  end

  describe '.load_from_file' do
    it 'loads scalar values' do
      language = create(:language, code: 'en')
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'dashboard' => { 'title' => 'Dashboard' }, 'save' => 'Save' } }.to_yaml)
      file.close

      described_class.load_from_file(file.path, 'en')

      expect(described_class.find_translation('dashboard.title', 'en').value).to eq('Dashboard')
      expect(described_class.find_translation('save', 'en').value).to eq('Save')
      expect(language).to be_persisted
    ensure
      file&.unlink
    end

    it 'loads translations using the legacy locale column path' do
      create(:language, code: 'en')
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'save' => 'Save' } }.to_yaml)
      file.close
      translation = instance_double(described_class)

      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)
      expect(described_class).to receive(:find_or_initialize_by)
        .with(key: 'save', locale: 'en').and_return(translation)
      expect(translation).to receive(:update!).with(value: 'Save')

      described_class.load_from_file(file.path, 'en')
    ensure
      file&.unlink
    end

    it 'returns when file is absent' do
      expect(described_class.load_from_file('/tmp/delta-pos-missing.yml', 'en')).to be_nil
    end

    it 'returns when locale is absent' do
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'es' => { 'save' => 'Guardar' } }.to_yaml)
      file.close

      expect(described_class.load_from_file(file.path, 'en')).to be_nil
    ensure
      file&.unlink
    end

    it 'returns when language is absent' do
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'fr' => { 'save' => 'Save' } }.to_yaml)
      file.close

      expect(described_class.load_from_file(file.path, 'fr')).to be_nil
    ensure
      file&.unlink
    end
  end

  describe '#locale' do
    it 'returns associated language code' do
      language = create(:language, code: 'es')
      expect(build(:translate, language:).locale).to eq('es')
    end

    it 'uses legacy locale attribute' do
      translate = described_class.new(locale: 'es')
      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)

      expect(translate.locale).to eq('es')
    end
  end

  describe 'uniqueness' do
    it 'rejects duplicate keys in a language' do
      language = create(:language, code: 'en')
      create(:translate, language:, key: 'duplicate.key')
      duplicate = build(:translate, language:, key: 'duplicate.key')

      expect(duplicate).to be_invalid
      expect(duplicate.errors[:key]).to include('already exists for this language')
    end

    it 'allows same key in another language' do
      create(:translate, language: create(:language, code: 'en'), key: 'shared.key')

      expect(build(:translate, language: create(:language, code: 'es'), key: 'shared.key')).to be_valid
    end

    it 'uses legacy locale uniqueness' do
      translate = described_class.new(key: 'shared.key', locale: 'en')
      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)
      allow(described_class).to receive(:exists?).with(key: 'shared.key', locale: 'en').and_return(true)

      translate.valid?

      expect(translate.errors[:key]).to include('already exists for this locale')
    end
  end
end
