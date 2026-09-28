# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organization, type: :model do
  subject(:organization) { build(:organization) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_inclusion_of(:status).in_array(%w[active inactive]) }

  it 'has many subscriptions' do
    expect(organization).to respond_to(:subscriptions)
  end
end
