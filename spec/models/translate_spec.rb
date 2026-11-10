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
      expect(described_class.find_translation('save', 'en').yaml_value).to eq('Save')
      expect(language).to be_persisted
    ensure
      file&.unlink
    end

    it 'loads translations using the legacy locale column path' do
      create(:language, code: 'en')
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'save' => 'Save' } }.to_yaml)
      file.close
      translation = instance_double(described_class, persisted?: false, new_record?: true)

      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)
      expect(described_class).to receive(:find_or_initialize_by)
        .with(key: 'save', locale: 'en').and_return(translation)
      expect(translation).to receive(:update!).with(yaml_value: 'Save', value: 'Save')

      described_class.load_from_file(file.path, 'en')
    ensure
      file&.unlink
    end

    it 'updates an imported baseline when YAML changes without overwriting a custom value' do
      language = create(:language, code: 'en')
      file = Tempfile.new(['translations', '.yml'])
      file.close
      File.write(file.path, { 'en' => { 'dashboard' => { 'title' => 'Original' } } }.to_yaml)

      described_class.load_from_file(file.path, 'en')
      translation = described_class.find_translation('dashboard.title', 'en')
      expect(translation.yaml_value).to eq('Original')

      File.write(file.path, { 'en' => { 'dashboard' => { 'title' => 'Updated YAML' } } }.to_yaml)
      described_class.load_from_file(file.path, 'en')

      expect(translation.reload.value).to eq('Updated YAML')
      expect(translation.yaml_value).to eq('Updated YAML')
      expect(language).to be_persisted
    ensure
      file&.unlink
    end

    it 'preserves an administrator override while advancing the YAML baseline' do
      create(:language, code: 'en')
      file = Tempfile.new(['translations', '.yml'])
      file.close
      File.write(file.path, { 'en' => { 'save' => 'Original YAML' } }.to_yaml)

      described_class.load_from_file(file.path, 'en')
      translation = described_class.find_translation('save', 'en')
      translation.update!(value: 'Custom override')

      File.write(file.path, { 'en' => { 'save' => 'Updated YAML' } }.to_yaml)
      described_class.load_from_file(file.path, 'en')

      expect(translation.reload.value).to eq('Custom override')
      expect(translation.yaml_value).to eq('Updated YAML')
    ensure
      file&.unlink
    end

    it 'conservatively preserves unknown legacy values on their first YAML sync' do
      language = create(:language, code: 'en')
      translation = create(:translate, language:, key: 'save', value: 'Unknown legacy value', yaml_value: nil)
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'save' => 'Current YAML' } }.to_yaml)
      file.close

      described_class.load_from_file(file.path, 'en')

      expect(translation.reload.value).to eq('Unknown legacy value')
      expect(translation.yaml_value).to eq('Current YAML')
    ensure
      file&.unlink
    end

    it 'skips blank YAML values instead of raising on validation' do
      create(:language, code: 'en')
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'empty' => '', 'real' => 'Translation' } }.to_yaml)
      file.close

      described_class.load_from_file(file.path, 'en')

      expect(described_class.find_translation('empty', 'en')).to be_nil
      expect(described_class.find_translation('real', 'en').value).to eq('Translation')
    ensure
      file&.unlink
    end

    it 'keeps a database override when importing the same YAML file again' do
      language = create(:language, code: 'en')
      translation = create(:translate, language:, key: 'save', value: 'Custom override')
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'save' => 'Save from YAML', 'new' => 'New entry' } }.to_yaml)
      file.close

      described_class.load_from_file(file.path, 'en')

      expect(translation.reload.value).to eq('Custom override')
      expect(translation.yaml_value).to eq('Save from YAML')
      expect(described_class.find_translation('new', 'en').value).to eq('New entry')
    ensure
      file&.unlink
    end

    it 'replaces an override only with an explicitly requested overwrite' do
      language = create(:language, code: 'en')
      translation = create(:translate, language:, key: 'save', value: 'Custom override')
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'save' => 'Save from YAML' } }.to_yaml)
      file.close

      described_class.load_from_file(file.path, 'en', overwrite: true)

      expect(translation.reload.value).to eq('Save from YAML')
      expect(translation.yaml_value).to eq('Save from YAML')
    ensure
      file&.unlink
    end

    it 'leaves database content untouched during a dry run, including missing keys' do
      language = create(:language, code: 'en')
      translation = create(:translate, language:, key: 'save', value: 'Custom override')
      file = Tempfile.new(['translations', '.yml'])
      file.write({ 'en' => { 'save' => 'YAML version', 'new' => 'Not written' } }.to_yaml)
      file.close

      described_class.load_from_file(file.path, 'en', overwrite: true, dry_run: true)

      expect(translation.reload.value).to eq('Custom override')
      expect(described_class.find_translation('new', 'en')).to be_nil
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

  describe 'shared translation revision' do
    it 'propagates the i18n revision between separate Redis cache clients' do
      skip 'Requires REDIS_URL' if ENV['REDIS_URL'].blank?

      options = { url: ENV.fetch('REDIS_URL'), namespace: "delta-pos:i18n:spec:#{SecureRandom.hex(6)}" }
      first = ActiveSupport::Cache::RedisCacheStore.new(**options)
      second = ActiveSupport::Cache::RedisCacheStore.new(**options)

      allow(Rails).to receive(:cache).and_return(first)
      described_class.invalidate_cache!
      published = second.read(described_class::CACHE_KEY)
      expect(published).to be_present

      allow(Rails).to receive(:cache).and_return(second)
      described_class.instance_variable_set(:@checked_at, nil)
      expect(described_class.cache_revision.last).to eq(published)
    ensure
      first&.delete(described_class::CACHE_KEY)
      described_class.instance_variable_set(:@checked_at, nil)
      described_class.instance_variable_set(:@shared_revision, nil)
    end

    it 'checks a revision published by another process through the shared cache' do
      shared_cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(shared_cache)
      described_class.instance_variable_set(:@checked_at, nil)
      described_class.cache_revision

      shared_cache.write(described_class::CACHE_KEY, 'other-worker-revision')
      described_class.instance_variable_set(:@checked_at, nil)

      expect(described_class.cache_revision.last).to eq('other-worker-revision')
    ensure
      described_class.instance_variable_set(:@checked_at, nil)
      described_class.instance_variable_set(:@shared_revision, nil)
    end
  end

  describe 'database-backed I18n refresh' do
    it 'applies overrides, updates them, and falls back after deletion' do
      language = create(:language, code: 'es', name: 'Español', flag_iso: 'mx')
      key = 'admin.languages.index.title'
      original = I18n.t(key, locale: :es)
      translation = create(:translate, language:, key:, value: 'Idiomas personalizados')

      expect(I18n.t(key, locale: :es)).to eq('Idiomas personalizados')
      translation.update!(value: 'Idiomas actualizados')
      expect(I18n.t(key, locale: :es)).to eq('Idiomas actualizados')

      translation.destroy!
      expect(I18n.t(key, locale: :es)).to eq(original)
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

    it 'rejects duplicate key changes before reaching the database unique index' do
      language = create(:language, :english)
      create(:translate, language:, key: 'reserved.key')
      translation = create(:translate, language:, key: 'other.key')

      expect(translation.update(key: 'reserved.key')).to be(false)
      expect(translation.errors[:key]).to be_present
    end

    it 'allows same key in another language' do
      create(:translate, language: create(:language, code: 'en'), key: 'shared.key')

      expect(build(:translate, language: create(:language, code: 'es'), key: 'shared.key')).to be_valid
    end

    it 'uses legacy locale uniqueness' do
      translate = described_class.new(key: 'shared.key', locale: 'en')
      allow(described_class).to receive(:column_exists?).with(:language_id).and_return(false)
      relation = instance_double(ActiveRecord::Relation)
      expect(described_class).to receive(:where).with(key: 'shared.key', locale: 'en').and_return(relation)
      expect(relation).to receive(:exists?).and_return(true)

      translate.valid?

      expect(translate.errors[:key]).to include('already exists for this locale')
    end
  end
end
