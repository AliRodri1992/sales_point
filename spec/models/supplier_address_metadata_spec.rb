# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Polymorphic address metadata', type: :model do
  it 'allows only one active primary address per supplier' do
    supplier = create(:supplier)
    create(:address, addressable: supplier, primary: true)
    duplicate = build(:address, addressable: supplier, primary: true)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:primary]).to be_present
    expect(build(:address, addressable: create(:supplier), primary: true)).to be_valid
  end

  it 'provides a localized, field-specific message for duplicate primary addresses' do
    supplier = create(:supplier)
    create(:address, :fiscal, :primary, addressable: supplier)

    messages = {
      es: 'La dirección principal ya está asignada a otra dirección de este tipo.',
      en: 'A primary address has already been assigned to another address of this type.',
      ko: '대표 주소는 이미 같은 유형의 다른 주소에 지정되어 있습니다.'
    }

    messages.each do |locale, message|
      I18n.with_locale(locale) do
        duplicate = build(:address, :fiscal, :primary, addressable: supplier)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors.full_messages_for(:primary)).to include(message)
      end
    end
  end

  it 'allows another primary after the original is soft deleted' do
    supplier = create(:supplier)
    original = create(:address, addressable: supplier, primary: true)
    original.update!(deleted_at: Time.current)

    expect(build(:address, addressable: supplier, primary: true)).to be_valid
  end

  it 'rejects restoration when a new primary address exists' do
    supplier = create(:supplier)
    original = create(:address, addressable: supplier, primary: true)
    original.update!(deleted_at: Time.current)
    create(:address, addressable: supplier, primary: true)

    expect(original.restore_safely).to be false
    expect(original.reload.deleted_at).to be_present
  end

  it 'supports distinct address purposes' do
    expect(build(:address, purpose: 'fiscal')).to be_valid
    expect(build(:address, purpose: 'unknown')).not_to be_valid
  end
  it 'preserves the deleted timestamp after a restoration conflict' do
    supplier = create(:supplier)
    original = create(:address, addressable: supplier, primary: true)
    original.update!(deleted_at: Time.current)
    deleted_at = original.deleted_at
    create(:address, addressable: supplier, primary: true)

    expect(original.restore_safely).to be false
    expect(original.deleted_at).to eq(deleted_at)
  end

  it 'does not restore an address that is not deleted' do
    expect(create(:address).restore_safely).to be false
  end
end
