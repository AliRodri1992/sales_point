# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe FinancialEncryption::Configuration do
  around do |example|
    Dir.mktmpdir('delta-financial-encryption') do |directory|
      @local_path = File.join(directory, 'financial_encryption.local.json')
      example.run
    end
  end

  def resolved(environment: 'development', environ: {}, credentials: -> {})
    described_class.resolve(environ:, credentials:, environment:, local_path: @local_path)
  end

  it 'creates private, persistent development keys and reuses them on subsequent boots' do
    first = resolved

    expect(first.keys).to match_array(FinancialEncryption::KEY_NAMES)
    expect(first.values).to all(match(/\A[0-9a-f]{64}\z/))
    expect(File.stat(@local_path).mode & 0o077).to eq(0)
    expect(resolved).to eq(first)
    expect(JSON.parse(File.read(@local_path))).to eq(first)
  end

  it 'keeps the same keys when multiple processes initialize together' do
    results = Array.new(4) { Thread.new { resolved } }.map(&:value)

    expect(results.uniq.length).to eq(1)
    expect(JSON.parse(File.read(@local_path))).to eq(results.first)
  end

  it 'uses explicit environment keys without reading credentials or writing a local file' do
    values = FinancialEncryption::KEY_NAMES.index_with { |name| "external-#{name}-secret-value" }
    environ = values.to_h { |name, value| ["ACTIVE_RECORD_ENCRYPTION_#{name.upcase}", value] }

    expect(resolved(environ:, credentials: -> { raise 'Credentials must not be read' })).to eq(values)
    expect(File.exist?(@local_path)).to be(false)
  end

  it 'uses Rails credentials when environment keys are absent' do
    values = FinancialEncryption::KEY_NAMES.index_with { |name| "credential-#{name}-secret-value" }

    expect(resolved(credentials: -> { values.transform_keys(&:to_sym) })).to eq(values)
    expect(File.exist?(@local_path)).to be(false)
  end

  it 'allows individual environment values to override credentials' do
    values = FinancialEncryption::KEY_NAMES.index_with { |name| "credential-#{name}-secret-value" }
    environ = { 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'replacement-primary-key' }

    expect(resolved(environ:, credentials: -> { values })).to eq(
      values.merge('primary_key' => 'replacement-primary-key')
    )
  end

  it 'rejects incomplete external keys instead of mixing them with generated secrets' do
    expect do
      resolved(environ: { 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'only-one-key' })
    end.to raise_error(FinancialEncryption::IncompleteConfiguration, /deterministic_key/)

    expect(File.exist?(@local_path)).to be(false)
  end

  it 'rejects invalid saved keys instead of silently replacing them' do
    File.write(@local_path, '{"primary_key":"invalid"}')

    expect { resolved }.to raise_error(FinancialEncryption::IncompleteConfiguration, /Restore/)
    expect(File.read(@local_path)).to eq('{"primary_key":"invalid"}')
  end

  it 'never generates development keys for test or production' do
    expect(resolved(environment: 'test')).to eq({})
    expect(resolved(environment: 'production')).to eq({})
    expect(File.exist?(@local_path)).to be(false)
  end
end
