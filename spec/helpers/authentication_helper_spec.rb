# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthenticationHelper, type: :helper do
  describe '#authentication_logo' do
    it 'returns the local logo asset name' do
      expect(helper.authentication_logo).to eq('logo.svg')
    end
  end

  describe '#authentication_title' do
    it 'translates the Devise sign-in title' do
      allow(helper).to receive(:t).with('devise.sessions.new.title').and_return('Sign in')

      expect(helper.authentication_title).to eq('Sign in')
    end
  end
end
