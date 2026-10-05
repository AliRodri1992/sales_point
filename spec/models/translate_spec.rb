# frozen_string_literal: true

RSpec.describe Translate, type: :model do
  let(:language) { create(:language, code: 'en', name: 'English', flag_iso: 'us') }

  it 'flattens nested translation hashes' do
    expect(described_class.flatten_hash({ home: { title: 'Home', nested: { label: 'Label' } } })).to eq(
      'home.title' => 'Home',
      'home.nested.label' => 'Label'
    )
  end

  it 'finds and returns values through locale-aware queries' do
    create(:translate, language:, key: 'home.title', value: 'Home')

    expect(described_class.by_language(language)).to exist
    expect(described_class.by_locale('en')).to exist
    expect(described_class.by_key('home.title')).to exist
    expect(described_class.find_by_key_and_locale('home.title', 'en').value).to eq('Home')
    expect(described_class.value_for('home.title', 'en')).to eq('Home')
    expect(described_class.value_for('missing', 'en', 'Fallback')).to eq('Fallback')
  end

  it 'loads leaf translations from a locale YAML file' do
    file = Tempfile.new(['translations', '.yml'])
    file.write("en:\n  home:\n    title: Home\n    nested:\n      label: Label\n")
    file.close

    described_class.load_from_file(file.path, 'en')

    expect(described_class.find_by_key_and_locale('home.title', 'en').value).to eq('Home')
    expect(described_class.find_by_key_and_locale('home.nested.label', 'en').value).to eq('Label')
  ensure
    file&.unlink
  end

  it 'returns the associated language locale code' do
    translate = create(:translate, language:, key: 'home.title', value: 'Home')

    expect(translate.locale).to eq('en')
  end
end
