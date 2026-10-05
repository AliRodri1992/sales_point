# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Theme do
  it 'returns the catalog and ids' do
    expect(described_class.all).to eq(described_class::ALL)
    expect(described_class.ids).to eq(described_class::ALL.pluck(:id))
  end

  it 'checks known and unknown ids' do
    expect(described_class.exists?(described_class::DEFAULT)).to be(true)
    expect(described_class.exists?('theme-missing')).to be(false)
  end

  it 'finds known and unknown themes' do
    expect(described_class.find(described_class::DEFAULT)[:id]).to eq(described_class::DEFAULT)
    expect(described_class.find('theme-missing')).to be_nil
  end
end
