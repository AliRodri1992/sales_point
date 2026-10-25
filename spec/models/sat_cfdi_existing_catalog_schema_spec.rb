# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SAT CFDI 4.0 legacy catalog schema', type: :model do
  it 'allows eight-decimal currencies without contradictory constraints' do
    constraints = ActiveRecord::Base.connection.check_constraints(:sat_currencies)
    expressions = constraints.map(&:expression).join(' ')

    expect(expressions).to include('8')
    expect(expressions).not_to include('decimals >= 0 AND decimals <= 6')
  end

  it 'supports month and bimester keys through 18 in database constraints' do
    constraints = ActiveRecord::Base.connection.check_constraints(:sat_months)
    expressions = constraints.map(&:expression).join(' ')

    expect(expressions).to include('1[0-8]')
    expect(expressions).to include('18')
    expect(expressions).not_to include('1[0-2]')
  end

  it 'has independent physical and legal person applicability columns' do
    expect(SatFiscalRegime.column_names).to include('applies_to_individual', 'applies_to_company')
    expect(SatFiscalRegime.columns_hash.fetch('person_type').null).to be(true)
  end
end
