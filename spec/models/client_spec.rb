require 'rails_helper'

RSpec.describe Client, type: :model do
  subject(:client) { build(:client) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(client).to be_valid
    end

    it 'requires code' do
      client.code = nil
      expect(client).not_to be_valid
    end

    it 'requires name' do
      client.name = nil
      expect(client).not_to be_valid
    end

    it 'rejects an invalid email' do
      client.email = 'invalid-email'
      expect(client).not_to be_valid
    end

    it 'rejects an invalid RFC' do
      client.rfc = 'INVALID'
      expect(client).not_to be_valid
    end

    it 'rejects an invalid postal code' do
      client.postal_code = '1234'
      expect(client).not_to be_valid
    end

    it 'rejects a negative credit limit' do
      client.credit_limit = -1
      expect(client).not_to be_valid
    end

    it 'validates code uniqueness among non-deleted clients' do
      create(:client, code: 'CLI-0001')

      duplicate = build(:client, code: 'CLI-0001')
      deleted = build(:client, code: 'CLI-0001', deleted_at: Time.current)

      expect(duplicate).not_to be_valid
      expect(deleted).to be_valid
    end

    it 'validates RFC uniqueness among non-deleted clients' do
      create(:client, rfc: 'XAXX010101001')

      duplicate = build(:client, rfc: 'XAXX010101001')
      deleted = build(:client, rfc: 'XAXX010101001', deleted_at: Time.current)

      expect(duplicate).not_to be_valid
      expect(deleted).to be_valid
    end
  end

  describe 'normalization' do
    it 'normalizes fields before validation' do
      client.code = '  CLI-0001  '
      client.name = '  Cliente Demo  '
      client.email = '  CLIENTE@EXAMPLE.COM  '
      client.phone = ' 5555555555 '
      client.rfc = ' xaxx010101001 '
      client.postal_code = ' 06000 '
      client.notes = '  Nota  '

      client.valid?

      expect(client.code).to eq('CLI-0001')
      expect(client.name).to eq('Cliente Demo')
      expect(client.email).to eq('cliente@example.com')
      expect(client.phone).to eq('5555555555')
      expect(client.rfc).to eq('XAXX010101001')
      expect(client.postal_code).to eq('06000')
      expect(client.notes).to eq('Nota')
    end

    it 'stores blank optional values as nil' do
      client.email = ' '
      client.phone = ' '
      client.rfc = ' '
      client.postal_code = ' '
      client.notes = ' '

      client.valid?

      expect(client.email).to be_nil
      expect(client.phone).to be_nil
      expect(client.rfc).to be_nil
      expect(client.postal_code).to be_nil
      expect(client.notes).to be_nil
    end
  end

  describe 'scopes' do
    it '.not_deleted excludes soft-deleted clients' do
      active_client = create(:client)
      deleted_client = create(:client, :deleted)

      expect(Client.not_deleted).to include(active_client)
      expect(Client.not_deleted).not_to include(deleted_client)
    end

    it '.available returns active non-deleted clients' do
      active_client = create(:client, status: :active)
      inactive_client = create(:client, status: :inactive)
      deleted_client = create(:client, :deleted, status: :active)

      expect(Client.available).to include(active_client)
      expect(Client.available).not_to include(inactive_client)
      expect(Client.available).not_to include(deleted_client)
    end
  end

  describe 'associations' do
    it 'allows the fiscal regime to be optional' do
      expect(client.sat_fiscal_regime).to be_nil
    end
  end
end
