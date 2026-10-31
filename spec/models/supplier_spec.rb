require 'rails_helper'

RSpec.describe Supplier, type: :model do
  let(:organization) { create(:organization) }
  subject(:supplier) { build(:supplier, organization:) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(supplier).to be_valid
    end

    it 'does not cache an empty address collection during supplier creation' do
      saved = create(:supplier, organization:)

      expect(saved.association(:addresses)).not_to be_loaded
    end

    it 'requires a valid person type' do
      supplier.person_type = nil
      expect(supplier).not_to be_valid
      expect(supplier.errors.attribute_names).to include(:person_type)
    end

    it 'requires a foreign tax identifier instead of an RFC for a foreign fiscal address' do
      country = create(:country, iso_alpha2: 'US')
      supplier.addresses.build(
        country:, purpose: 'fiscal', primary: true, street: 'Main St',
        city: 'Austin', state: 'TX', postal_code: '78701'
      )
      supplier.rfc = nil
      supplier.foreign_tax_id = 'US-98-7654321'

      expect(supplier).to be_valid
      expect(supplier.rfc).to be_nil
    end

    it 'rejects a mismatched Mexican SAT regime' do
      supplier.sat_fiscal_regime = create(:sat_fiscal_regime, person_type: 'M')
      expect(supplier).not_to be_valid
      expect(supplier.errors.attribute_names).to include(:sat_fiscal_regime)
    end

    it 'requires code and name' do
      supplier.code = nil
      supplier.name = nil
      expect(supplier).not_to be_valid
    end

    it 'rejects invalid email and RFC data' do
      supplier.email = 'invalid-email'
      supplier.rfc = 'INVALID'
      expect(supplier).not_to be_valid
    end

    it 'requires RFC and supplier name' do
      supplier.assign_attributes(rfc: ' ', name: ' ')
      expect(supplier).not_to be_valid
      expect(supplier.errors.attribute_names).to include(:rfc, :name)
    end

    it 'rejects RFCs with impossible calendar dates' do
      supplier.rfc = 'ABCD990230AAA'
      expect(supplier).not_to be_valid
      expect(supplier.errors.details[:rfc]).to include(hash_including(error: :invalid_date))
    end

    it 'checks RFC length against the selected person type' do
      supplier.assign_attributes(person_type: 'company', rfc: 'ABCD900101AAA')
      expect(supplier).not_to be_valid
      expect(supplier.errors.details[:rfc]).to include(hash_including(error: :person_type_mismatch))
    end

    it 'normalizes RFC case before validating' do
      supplier.rfc = ' abcd900101aaa '
      supplier.valid?
      expect(supplier.rfc).to eq('ABCD900101AAA')
    end

    it 'validates code uniqueness among non-deleted suppliers' do
      create(:supplier, organization:, code: 'SUP-0001')
      expect(build(:supplier, organization:, code: 'SUP-0001')).not_to be_valid

      # A deleted supplier's code can be reused
      create(:supplier, organization:, code: 'SUP-0002', deleted_at: Time.current)
      expect(build(:supplier, organization:, code: 'SUP-0002')).to be_valid
    end

    it 'validates RFC uniqueness among non-deleted suppliers' do
      create(:supplier, organization:, rfc: 'XAXX010101001')
      expect(build(:supplier, organization:, rfc: 'XAXX010101001')).not_to be_valid

      # A deleted supplier's RFC can be reused
      create(:supplier, organization:, rfc: 'XAXX010101002', deleted_at: Time.current)
      expect(build(:supplier, organization:, rfc: 'XAXX010101002')).to be_valid
    end
  end

  it 'does not store a duplicate supplier-level postal code' do
    expect(described_class.column_names).not_to include('postal_code')
  end

  describe 'catalog associations' do
    it { is_expected.to belong_to(:currency) }
  end

  describe 'commercial profile' do
    it 'accepts valid commercial terms' do
      supplier.assign_attributes(legal_name: 'Empresa SA', trade_name: 'Marca', alias_name: 'Distribuidor',
                                 classification: 'distributor', person_type: 'company',
                                 rfc: 'ABC010101023', currency: build(:currency),
                                 credit_days: 30, credit_limit: 1000, discount_percent: 10,
                                 minimum_order_amount: 100)
      expect(supplier).to be_valid
    end

    it 'rejects invalid credit and discounts' do
      supplier.assign_attributes(credit_days: -1, credit_limit: -10, discount_percent: 101,
                                 minimum_order_amount: -1)
      expect(supplier).not_to be_valid
    end
  end

  describe 'organization ownership' do
    it 'allows the same supplier code in different organizations' do
      first = create(:organization)
      second = create(:organization)
      create(:supplier, organization: first, code: 'SHARED', rfc: 'XAXX010101111')

      other = build(:supplier, organization: second, code: 'SHARED', rfc: 'XAXX010101111')
      expect(other).to be_valid
    end

    it 'rejects duplicate codes within one organization' do
      organization = create(:organization)
      create(:supplier, organization:, code: 'SHARED')
      expect(build(:supplier, organization:, code: 'SHARED')).not_to be_valid
    end
  end

  describe 'normalization' do
    it 'normalizes fields and blanks' do
      supplier.assign_attributes(
        code: '  SUP-0001  ', name: '  Proveedor Demo  ',
        email: '  PROVEEDOR@EXAMPLE.COM  ', phone: ' 5555555555 ',
        rfc: ' xaxx010101001 ', notes: '  Nota  '
      )
      supplier.valid?
      expect(supplier.attributes.values_at('code', 'name', 'email', 'phone', 'rfc', 'notes'))
        .to eq(['SUP-0001', 'Proveedor Demo', 'proveedor@example.com', '+525555555555',
                'XAXX010101001', 'Nota'])
    end
  end

  describe 'tags_text' do
    it 'normalizes and preserves the comma-separated tags used by the chip editor' do
      supplier.tags_text = '  Local, Prioritario, Local, , Servicios  '

      expect(supplier.tags).to eq(%w[Local Prioritario Servicios])
      expect(supplier.tags_text).to eq('Local, Prioritario, Servicios')
    end

    it 'enforces the existing maximum of 20 tags on the server' do
      supplier.tags_text = (1..25).map { |number| "Etiqueta #{number}" }.join(', ')

      expect(supplier.tags.length).to eq(20)
      expect(supplier.tags.last).to eq('Etiqueta 20')
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

  describe 'responsible user assignment' do
    it 'rejects a responsible user outside the supplier organization' do
      supplier.responsible_user = create(:user)

      expect(supplier).not_to be_valid
      expect(supplier.errors[:responsible_user]).to be_present
    end

    it 'rejects assigning a responsible user whose organization membership was deactivated' do
      responsible = create(:user)
      membership = create(:organization_membership, organization:, user: responsible)
      membership.update!(status: :inactive)
      supplier.responsible_user = responsible

      expect(supplier).not_to be_valid
      expect(supplier.errors[:responsible_user]).to be_present
    end

    it 'accepts an assigned responsible user with an organization membership' do
      responsible = create(:user)
      create(:organization_membership, organization:, user: responsible)
      supplier.responsible_user = responsible

      expect(supplier).to be_valid
    end

    it 'rejects a responsible user when the supplier has no organization' do
      supplier.organization = nil
      supplier.responsible_user = create(:user)

      expect(supplier).not_to be_valid
      expect(supplier.errors[:responsible_user]).to be_present
    end
  end

  it 'does not modify a text field when a normalization block was not supplied' do
    supplier.name = '  Unnormalized value  '
    supplier.send(:normalize_text_field, :name)
    expect(supplier.name).to eq('  Unnormalized value  ')
  end
end
