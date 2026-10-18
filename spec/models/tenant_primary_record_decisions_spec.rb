# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tenant-scoped primary and preferred record rules' do
  let(:organization) { create(:organization) }
  let(:supplier) { create(:supplier, organization:) }
  let(:branch) { create(:branch, organization:) }

  describe Address do
    it 'does not allow two active primary fiscal addresses on the same supplier' do
      create(:address, addressable: supplier, purpose: 'fiscal', primary: true)
      duplicate = build(:address, addressable: supplier, purpose: 'fiscal', primary: true)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.details[:primary]).to include(hash_including(error: :taken))
    end

    it 'allows different primary address purposes for the same supplier' do
      create(:address, addressable: supplier, purpose: 'fiscal', primary: true)
      shipping = build(:address, addressable: supplier, purpose: 'delivery', primary: true)
      expect(shipping).to be_valid
    end

    it 'does not apply active-primary uniqueness rules to archived addresses' do
      create(:address, addressable: supplier, purpose: 'fiscal', primary: true)
      archived = build(:address, addressable: supplier, purpose: 'fiscal',
                                 primary: true, deleted_at: Time.current)
      expect(archived).to be_valid
    end

    it 'allows another nonprimary address in the same category' do
      create(:address, addressable: supplier, purpose: 'fiscal', primary: true)
      secondary = build(:address, addressable: supplier, purpose: 'fiscal', primary: false)
      expect(secondary).to be_valid
    end

    it 'allows the same primary address on a separate organization' do
      create(:address, addressable: supplier, purpose: 'fiscal', primary: true)
      other = build(:address, addressable: create(:supplier, organization: create(:organization)),
                              purpose: 'fiscal', primary: true)
      expect(other).to be_valid
    end
  end

  describe Contact do
    it 'rejects a second primary active supplier contact' do
      create(:contact, contactable: supplier, primary: true)
      contact = build(:contact, contactable: supplier, primary: true)
      expect(contact).not_to be_valid
      expect(contact.errors.details[:primary]).to include(hash_including(error: :taken))
    end

    it 'allows secondary contacts alongside a primary supplier contact' do
      create(:contact, contactable: supplier, primary: true)
      expect(build(:contact, contactable: supplier, primary: false)).to be_valid
    end

    it 'allows an inactive primary contact record' do
      create(:contact, contactable: supplier, primary: true)
      expect(build(:contact, contactable: supplier, primary: true, active: false)).to be_valid
    end

    it 'allows a deleted primary contact without blocking existing active ones' do
      create(:contact, contactable: supplier, primary: true)
      expect(build(:contact, contactable: supplier, primary: true, deleted_at: Time.current)).to be_valid
    end
  end

  describe SupplierProduct do
    let(:product) { create(:product, organization:) }
    let(:attributes) do
      { organization:, supplier:, product:, currency: supplier.currency,
        presentation_name: 'Unit', units_per_package: 1, purchase_price: 10, minimum_quantity: 1 }
    end

    it 'allows assigning a preferred supplier after registering an active offer' do
      offer = described_class.create!(**attributes)
      product.update!(preferred_supplier: supplier)

      expect(offer.reload).to be_preferred
    end

    it 'allows another supplier offer without overwriting the preferred supplier' do
      described_class.create!(**attributes)
      product.update!(preferred_supplier: supplier)
      other_supplier = create(:supplier, organization:)
      alternative = described_class.new(**attributes, supplier: other_supplier)

      expect(alternative).to be_valid
      expect(product.reload.preferred_supplier).to eq(supplier)
    end

    it 'rejects a preferred supplier without an active offer' do
      other_supplier = create(:supplier, organization:)
      product.preferred_supplier = other_supplier

      expect(product).not_to be_valid
      expect(product.errors[:preferred_supplier]).to be_present
    end

    it 'rejects product offers belonging to a separate organization' do
      foreign_product = create(:product, organization: create(:organization))
      record = described_class.new(**attributes, product: foreign_product)
      expect(record).not_to be_valid
      expect(record.errors.details[:product]).to include(hash_including(error: :invalid))
    end
  end

  describe SupplierSchedule do
    it 'does not run cross-tenant schedule validation without an associated supplier' do
      visit = described_class.new(branch:, kind: 'visit', weekday: 1, starts_at: '09:00')
      visit.send(:same_organization)
      expect(visit.errors.details[:branch]).to be_empty
    end

    it 'does not run cross-tenant schedule validation without a branch' do
      visit = described_class.new(supplier:, kind: 'visit', weekday: 1, starts_at: '09:00')
      visit.send(:same_organization)
      expect(visit.errors.details[:branch]).to be_empty
    end

    it 'allows a schedule with a later end time' do
      visit = described_class.new(supplier:, branch:, kind: 'visit', weekday: 1,
                                  starts_at: '09:00', ends_at: '10:00')
      expect(visit).to be_valid
    end
  end
end
