require 'rails_helper'

RSpec.describe TranslationGenerationService do
  describe '#call' do
    it 'preserves existing translations' do
      source = create(:language, code: 'es', locale: 'es')
      target = create(:language, code: 'fr', locale: 'fr')
      generation = create(:translation_generation, language: target, source_language: source)

      create(:translate, language: target, key: 'customers.title', value: 'Clientes')

      allow(TranslationCatalog).to receive(:new).and_return(
        instance_double(TranslationCatalog, call: { 'customers.title' => 'Clientes' })
      )
      allow(TranslationCatalog).to receive(:version_for).and_return(generation.source_catalog_version)

      provider = instance_double(TranslationProviders::LibreTranslateProvider)
      allow(TranslationProviders::LibreTranslateProvider).to receive(:new).and_return(provider)
      allow(provider).to receive(:translate_many).and_return(['Customers'])

      described_class.new(generation).call

      expect(target.translates.find_by(key: 'customers.title').value).to eq('Clientes')
    end

    it 'deduplicates identical source text in a batch' do
      source = create(:language, code: 'es', locale: 'es')
      target = create(:language, code: 'fr', locale: 'fr')
      generation = create(:translation_generation, language: target, source_language: source)

      allow(TranslationCatalog).to receive(:new).and_return(
        instance_double(
          TranslationCatalog,
          call: {
            'customers.one' => 'Cliente',
            'customers.two' => 'Cliente'
          }
        )
      )
      allow(TranslationCatalog).to receive(:version_for).and_return(generation.source_catalog_version)

      provider = instance_double(TranslationProviders::LibreTranslateProvider)
      allow(TranslationProviders::LibreTranslateProvider).to receive(:new).and_return(provider)
      allow(provider).to receive(:translate_many)
        .with(texts: ['Cliente'], source: 'es', target: 'fr')
        .and_return(['Client'])

      described_class.new(generation).call

      expect(target.translates.where(value: 'Client').count).to eq(1)
      expect(generation.reload.deduplicated_translations).to eq(1)
    end
  end
end
