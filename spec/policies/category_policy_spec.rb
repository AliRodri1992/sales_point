# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoryPolicy::Scope do
  it 'limits categories to the selected organization' do
    organization = create(:organization)
    other = create(:organization)
    owned = create(:category, organization:)
    create(:category, organization: other)

    CurrentOrganizationAccess.set(organization:, enforce_tenant: true) do
      resolved = described_class.new(build(:user), Category.all).resolve
      expect(resolved).to contain_exactly(owned)
    end
  end

  it 'returns no categories when no organization is selected' do
    scope = described_class.new(build(:user), Category.all).resolve
    expect(scope).to be_empty
  end
end
