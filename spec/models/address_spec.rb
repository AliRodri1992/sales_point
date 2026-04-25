require 'rails_helper'

RSpec.describe Address, type: :model do
  subject { build(:address) }

  # =========================
  # VALIDATIONS
  # =========================
  it 'is valid with valid attributes' do
    expect(subject).to be_valid
  end

  it 'is invalid without country' do
    subject.country = nil
    expect(subject).not_to be_valid
  end

  it 'is invalid without postal_code' do
    subject.postal_code = nil
    expect(subject).not_to be_valid
  end

  it 'validates latitude range' do
    subject.latitude = 200
    expect(subject).not_to be_valid
  end

  it 'validates longitude range' do
    subject.longitude = -200
    expect(subject).not_to be_valid
  end

  # =========================
  # ENUM
  # =========================
  it 'has valid geocoding statuses' do
    expect(Address.geocoding_statuses.keys)
      .to include('pending', 'success', 'failed')
  end

  # =========================
  # SCOPES
  # =========================
  describe 'scopes' do
    before do
      create_list(:address, 2, :success)
      create_list(:address, 1, :pending)
      create_list(:address, 1, :failed)
    end

    it '.geocoded returns success addresses' do
      expect(Address.geocoded.count).to eq(2)
    end

    it '.pending_geocoding returns pending addresses' do
      expect(Address.pending_geocoding.count).to eq(1)
    end

    it '.failed_geocoding returns failed addresses' do
      expect(Address.failed_geocoding.count).to eq(1)
    end
  end

  # =========================
  # PARANOIA / SOFT DELETE
  # =========================

  describe 'destroy' do
    it 'soft deletes record' do
      address = create(:address)

      expect do
        address.destroy
      end.to change(Address, :count).by(-1)
    end

    it 'sets deleted_at' do
      address = create(:address)

      address.destroy!

      expect(address.deleted_at).not_to be_nil
    end
  end

  describe 'restore' do
    it 'restores a deleted record' do
      address = create(:address)

      address.destroy!
      address.restore

      expect(Address.exists?(address.id)).to be true
    end
  end

  describe 'queries' do
    it 'includes deleted records in with_deleted' do
      address = create(:address)

      address.destroy!

      expect(Address.with_deleted).to include(address)
    end

    it 'returns only deleted records in only_deleted' do
      address = create(:address)

      address.destroy!

      expect(Address.only_deleted).to include(address)
    end
  end
  # =========================
  # HELPERS
  # =========================
  describe 'helpers' do
    describe '#full_address' do
      it 'builds full address string' do
        address = build(:address,
                        street: 'Av. Reforma',
                        city: 'CDMX',
                        country: 'MX',
                        postal_code: '06000')

        expect(address.full_address).to include('Av. Reforma')
        expect(address.full_address).to include('CDMX')
      end
    end

    describe '#coordinates' do
      it 'returns latitude and longitude' do
        address = build(:address, latitude: 19.4, longitude: -99.1)

        expect(address.coordinates).to eq([19.4, -99.1])
      end
    end

    describe '#geocoding helpers' do
      it '#geocoded? returns true when success' do
        address = build(:address, geocoding_status: :success)

        expect(address.geocoded?).to be true
      end

      it '#needs_geocoding? returns true when pending' do
        address = build(:address, geocoding_status: :pending)

        expect(address.needs_geocoding?).to be true
      end
    end
  end
end
