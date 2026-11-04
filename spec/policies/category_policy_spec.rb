# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryPolicy::Scope do
  it 'returns the supplied scope' do
    records = Category.all
    resolved_scope = described_class.new(build(:user), records).resolve
    expect(resolved_scope.to_sql).to eq(records.to_sql)
  end
end
