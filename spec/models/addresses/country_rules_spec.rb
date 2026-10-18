# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Addresses::CountryRules do
  {
    'AR' => ['C1425ABC', '1425'],
    'CO' => ['110111'],
    'CL' => ['8320000'],
    'PE' => ['15001'],
    'ZA' => ['2000'],
    'ES' => ['28013'],
    'IT' => ['00100'],
    'NL' => ['1012 AB'],
    'NZ' => ['6011'],
    'CN' => ['100000'],
    'SG' => ['018956']
  }.each do |country, valid_examples|
    it "accepts postal codes for #{country} and rejects invalid input" do
      rules = described_class.new(country)
      valid_examples.each { |example| expect(rules.valid_postal_code?(example)).to be(true) }
      expect(rules.valid_postal_code?('!bad')).to be(false)
    end
  end

  it 'requires a region for selected federal countries' do
    %w[MX US CA AU BR IN AR CO CL PE ZA].each do |country|
      expect(described_class.new(country).state_required?).to be(true)
    end
  end
end
