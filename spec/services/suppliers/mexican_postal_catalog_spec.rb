# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Local nationwide Mexican postal catalog' do
  it 'includes valid five-digit codes and all 32 federal entities' do
    states = Set.new
    codes = Set.new
    neighborhoods = 0
    (0..9).each do |digit|
      path = Rails.root.join('config/data/postal', "mx_#{digit}.json")
      expect(path).to exist
      catalog = JSON.parse(path.read)
      catalog.each do |code, location|
        expect(code).to match(/\A\d{5}\z/)
        expect(code.start_with?(digit.to_s)).to be true
        codes << code
        states << location.fetch(0)
        neighborhoods += location.fetch(2).length
      end
    end
    expect(states.length).to eq(32)
    expect(codes.length).to be >= 31_000
    expect(neighborhoods).to be >= 140_000
  end
end
