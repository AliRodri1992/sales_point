# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Polymorphic contact restoration', type: :model do
  it 'restores a deleted contact when its primary designation is available' do
    contact = create(:contact, primary: true)
    contact.update!(deleted_at: Time.current)

    expect(contact.restore_safely).to be true
    expect(contact.reload.deleted_at).to be_nil
  end

  it 'rejects restoration if another active primary exists' do
    organization = create(:organization)
    contact = create(:contact, contactable: organization, primary: true)
    contact.update!(deleted_at: Time.current)
    create(:contact, contactable: organization, primary: true)

    expect(contact.restore_safely).to be false
    expect(contact.reload.deleted_at).to be_present
  end
  it 'keeps the original deleted timestamp when restoration fails' do
    organization = create(:organization)
    contact = create(:contact, contactable: organization, primary: true)
    contact.update!(deleted_at: Time.current)
    original_timestamp = contact.deleted_at
    create(:contact, contactable: organization, primary: true)

    expect(contact.restore_safely).to be false
    expect(contact.deleted_at).to eq(original_timestamp)
  end

  it 'does not restore an already active contact' do
    contact = create(:contact)
    expect(contact.restore_safely).to be false
  end
end
