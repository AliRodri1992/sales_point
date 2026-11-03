# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::InvitationDeliveryToken do
  it 'encrypts invitation tokens before they enter background job arguments' do
    token = SecureRandom.urlsafe_base64(48)
    ciphertext = described_class.encrypt(token)
    expect(ciphertext).not_to include(token)
    expect(described_class.decrypt(ciphertext)).to eq(token)
    expect { described_class.decrypt('invalid') }.to raise_error(StandardError)
  end
end
