# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemRolesHelper, type: :helper do
  it 'preserves custom names and descriptions when editing a seeded role' do
    role = build(:system_role, code: 'cashier', name: 'Evening team', description: 'Evening operations')
    expect(helper.system_role_name(role)).to eq('Evening team')
    expect(helper.system_role_description(role)).to eq('Evening operations')
  end

  it 'continues translating unchanged seeded role names' do
    role = build(:system_role, code: 'cashier', name: 'Cajero')
    expect(helper.system_role_name(role)).to eq('Cashier')
  end
end
