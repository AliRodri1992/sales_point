require 'rails_helper'

RSpec.describe Supplier, type: :model do
  subject(:supplier) { build(:supplier) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(supplier).to be_valid
    end

    it 'requires code and name' do
      supplier.code = nil
      supplier.name = nil
      expect(supplier).not_to be_valid
    end

    it 'rejects invalid contact data' do
      supplier.email = 'invalid-email'
      supplier.rfc = 'INVALID'
      supplier.postal_code = '1234'
      expect(supplier).not_to be_valid
    end

    it 'validates code uniqueness among non-deleted suppliers' do
      create(:supplier, code: 'SUP-0001')
      expect(build(:supplier, code: 'SUP-0001')).not_to be_valid
      expect(build(:supplier, code: 'SUP-0001', deleted_at: Time.current)).to be_valid
    end

    it 'validates RFC uniqueness among non-deleted suppliers' do
      create(:supplier, rfc: 'XAXX010101001')
      expect(build(:supplier, rfc: 'XAXX010101001')).not_to be_valid
      expect(build(:supplier, rfc: 'XAXX010101001', deleted_at: Time.current)).to be_valid
    end
  end

  describe 'normalization' do
    it 'normalizes fields and blanks' do
      supplier.assign_attributes(
        code: '  SUP-0001  ', name: '  Proveedor Demo  ',
        email: '  PROVEEDOR@EXAMPLE.COM  ', phone: ' 5555555555 ',
        rfc: ' xaxx010101001 ', postal_code: ' 06000 ', notes: '  Nota  '
      )
      supplier.valid?
      expect(supplier.attributes.values_at('code', 'name', 'email', 'phone', 'rfc', 'postal_code', 'notes'))
        .to eq(%w[SUP-0001 Proveedor Demo proveedor@example.com 5555555555 XAXX010101001 06000 Nota])
    end
  end

  describe 'scopes' do
    it 'excludes deleted records from not_deleted and inactive/deleted from available' do
      active = create(:supplier, status: :active)
      inactive = create(:supplier, status: :inactive)
      deleted = create(:supplier, :deleted, status: :active)

      expect(Supplier.not_deleted).to include(active)
      expect(Supplier.not_deleted).not_to include(deleted)
      expect(Supplier.available).to include(active)
      expect(Supplier.available).not_to include(inactive, deleted)
    end
  end
end
