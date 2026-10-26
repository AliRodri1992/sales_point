# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SAT catalog migration chronology', type: :model do
  let(:catalog_migrations) do
    Rails.root.glob('db/migrate/*_create_sat_*.rb') +
      Rails.root.glob('db/migrate/*_align_existing_sat_catalogs_with_cfdi40.rb')
  end

  it 'places all 28 SAT catalog migrations before the initial countries migration' do
    versions = catalog_migrations.map { |path| path.basename.to_s.split('_').first }

    expect(versions.size).to eq(28)
    expect(versions.max).to be < '20260415180630'
    expect(versions.uniq.size).to eq(versions.size)
  end

  it 'aligns the existing SAT catalogs after all of their creation migrations' do
    alignment = catalog_migrations.find { |path| path.basename.to_s.include?('align_existing_sat_catalogs') }
    created = catalog_migrations.reject { |path| path == alignment }

    expect(alignment).to be_present
    expect(created.map { |path| path.basename.to_s }).to all(include('create_sat_'))
    expect(alignment.basename.to_s).to be > created.map { |path| path.basename.to_s }.max
  end
end
