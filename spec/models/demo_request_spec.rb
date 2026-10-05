# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoRequest, type: :model do
  pending 'requires database connection'

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:company) }
    it { is_expected.to validate_presence_of(:phone) }
  end
end
