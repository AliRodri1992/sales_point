# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CountryFlagsHelper, type: :helper do
  it 'includes local SVG assets for every country in the catalog' do
    countries = JSON.parse(Rails.root.join('db/seeds/data/countries.json').read)
    missing = countries.reject do |country|
      Rails.root.join("app/assets/images/flags/#{country.fetch('iso_alpha2').downcase}.svg").file?
    end

    expect(countries.size).to eq(249)
    expect(missing).to be_empty
  end

  it 'resolves a local flag for Mexico and does not fall back to a CDN' do
    country = instance_double(Country, iso_alpha2: 'MX')

    expect(helper.country_flag_asset_path(country)).to include('/assets/flags/mx')
  end

  it 'keeps unknown test country codes usable without an image' do
    country = instance_double(Country, iso_alpha2: 'HH')

    expect(helper.country_flag_asset_path(country)).to be_nil
  end
end
