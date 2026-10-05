# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'validations' do
    it 'validates presence of body' do
      message = build(:message, body: nil)
      expect(message).to be_invalid
      expect(message.errors[:body]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:user) }
  end
end
