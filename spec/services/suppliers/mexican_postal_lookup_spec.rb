# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Suppliers::MexicanPostalLookup do
  let(:response) { instance_double(Faraday::Response, success?: true, body: response_body) }
  let(:connection) { instance_double(Faraday::Connection, get: response) }
  let(:response_body) do
    { zip_codes: [
      { d_codigo: '54800', d_estado: 'Estado de México', d_mnpio: 'Cuautitlán',
        d_asenta: 'Centro' },
      { d_codigo: '54800', d_estado: 'Estado de México', d_mnpio: 'Cuautitlán',
        d_asenta: 'Santa María' },
      { d_codigo: '06000', d_estado: 'Ciudad de México', d_mnpio: 'Cuauhtémoc',
        d_asenta: 'Centro' }
    ] }.to_json
  end

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow_any_instance_of(described_class).to receive(:connection).and_return(connection)
  end

  it 'returns a municipality, state, and unique colonias for the exact Mexican postal code' do
    result = described_class.new('54800').call

    expect(result).to eq(
      found: true, state: 'Estado de México', municipality: 'Cuautitlán',
      neighborhoods: ['Centro', 'Santa María']
    )
    expect(connection).to have_received(:get).with('/api/v1/zip_codes', zip_code: '54800', per_page: 200)
  end

  it 'rejects incomplete or invalid postal codes without calling the provider' do
    %w[5480 5480A 548001].each do |value|
      expect(described_class.new(value).call).to be_nil
    end
    expect(connection).not_to have_received(:get)
  end

  it 'does not treat partial matches as a match' do
    expect(described_class.new('99999').call).to eq(found: false, neighborhoods: [])
  end

  it 'caches a successful result across lookups' do
    2.times { described_class.new('54800').call }
    expect(connection).to have_received(:get).once
  end

  it 'fails open if the postal provider is unavailable' do
    allow(connection).to receive(:get).and_raise(Faraday::TimeoutError)
    expect(described_class.new('54800').call).to be_nil
  end

  it 'fails open if the provider responds with malformed JSON' do
    allow(response).to receive(:body).and_return('{')
    expect(described_class.new('54800').call).to be_nil
  end

  it 'does not use unsuccessful responses as valid suggestions' do
    allow(response).to receive(:success?).and_return(false)
    expect(described_class.new('54800').call).to be_nil
  end

  it 'configures bounded timeouts for the external lookup' do
    options = described_class.new('54800').send(:connection).options
    expect(options.timeout).to eq(4)
    expect(options.open_timeout).to eq(2)
  end
end
