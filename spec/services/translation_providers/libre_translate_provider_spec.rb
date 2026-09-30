require 'rails_helper'

RSpec.describe TranslationProviders::LibreTranslateProvider do
  let(:connection) { instance_double(Faraday::Connection) }
  let(:response) do
    instance_double(
      Faraday::Response,
      success?: true,
      status: 200,
      body: { translatedText: ['Clientes'] }.to_json
    )
  end

  before do
    allow(Faraday).to receive(:new).and_return(connection)
    allow(connection).to receive(:post).and_return(response)
  end

  it 'translates a batch' do
    result = described_class.new.translate_many(texts: ['Clientes'], source: 'es', target: 'en')

    expect(result).to eq(['Clientes'])
  end

  it 'raises a transient error for rate limiting' do
    rate_limited = instance_double(
      Faraday::Response,
      success?: false,
      status: 429,
      body: 'rate limited'
    )
    allow(connection).to receive(:post).and_return(rate_limited)

    expect do
      described_class.new.translate_many(texts: ['Clientes'], source: 'es', target: 'en')
    end.to raise_error(TranslationProvider::TransientError)
  end
end
