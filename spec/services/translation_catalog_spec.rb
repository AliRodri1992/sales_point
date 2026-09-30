require 'rails_helper'

RSpec.describe TranslationCatalog do
  it 'returns a stable digest for a locale catalog' do
    expect(described_class.version_for('es')).to match(/A[a-f0-9]{64}z/)
  end

  it 'flattens string values from locale files' do
    catalog = described_class.new('es').call

    expect(catalog).to be_a(Hash)
    expect(catalog.values).to all(be_a(String))
  end
end
