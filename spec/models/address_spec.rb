# frozen_string_literal: true

RSpec.describe Address, type: :model do
  subject { build(:address) }

  describe 'associations' do
    it { is_expected.to belong_to(:addressable) }
  end

  describe 'country-specific address validation' do
    it 'requires all Mexican address fields and a five-digit postal code' do
      country = build(:country, iso_alpha2: 'MX')
      attributes = { country:, exterior_number: nil, neighborhood: nil,
                     state: nil, postal_code: 'ABC12' }
      address = build(:address, **attributes)
      expect(address).not_to be_valid
      %i[exterior_number neighborhood state postal_code].each do |field|
        expect(address.errors[field]).to be_present
      end
    end

    it 'supports US ZIP+4 and optional neighborhood and exterior number' do
      country = build(:country, iso_alpha2: 'US')
      attributes = { country:, exterior_number: nil, neighborhood: nil,
                     postal_code: '90210-1234' }
      address = build(:address, **attributes)
      expect(address).to be_valid
    end

    it 'supports Canadian alphanumeric and Korean postal formats' do
      address = build(:address, country: build(:country, iso_alpha2: 'CA'), postal_code: 'K1A 0B1')
      expect(address).to be_valid
      address.country.iso_alpha2 = 'KR'
      address.postal_code = '04524'
      expect(address).to be_valid
    end

    it 'allows countries without postal codes to omit the postal code and region' do
      country = build(:country, iso_alpha2: 'AE')
      attributes = { country:, postal_code: nil, neighborhood: nil,
                     state: nil, exterior_number: nil }
      address = build(:address, **attributes)
      expect(address).to be_valid
    end

    it 'rejects invalid postal formats for countries with known rules' do
      address = build(:address, country: build(:country, iso_alpha2: 'US'), postal_code: 'HELLO')
      expect(address).not_to be_valid
      expect(address.errors[:postal_code]).to be_present
    end
  end

  describe 'restoring an archived primary' do
    it 'refuses restoration when another active address is primary for its purpose' do
      supplier = create(:supplier)
      archived = create(:address, :fiscal, :primary, :deleted, addressable: supplier)
      create(:address, :fiscal, :primary, addressable: supplier)

      expect(archived.restore_safely).to be false
      expect(archived.reload.deleted_at).to be_present
      expect(archived.errors[:primary]).to be_present
    end

    it 'restores a primary when there is no active conflict' do
      supplier = create(:supplier)
      archived = create(:address, :delivery, :primary, :deleted, addressable: supplier)

      expect(archived.restore_safely).to be true
      expect(archived.reload).to be_primary
      expect(archived.deleted_at).to be_nil
    end
  end

  describe 'location freshness' do
    it 'clears stale coordinates and confirmation when any location component changes' do
      address = create(:address)
      address.update!(latitude: 19.4, longitude: -99.1,
                      location_confirmed_at: Time.current, geocoding_status: :success)
      address.update!(street: 'Different Street')
      expect(address).to have_attributes(latitude: nil, longitude: nil,
                                         location_confirmed_at: nil, geocoding_status: 'pending')
    end

    it 'preserves confirmed coordinates when explicitly confirming the new address' do
      address = create(:address)
      attributes = { street: 'A different street', latitude: 19.5, longitude: -99.2,
                     location_confirmed_at: Time.current, geocoding_status: :success }
      address.update!(**attributes)
      expect(address.reload.location_confirmed?).to be true
      expect(address.latitude.to_f).to eq(19.5)
    end

    it 'provides stable fingerprints for geocoding jobs' do
      address = build(:address)
      previous = address.geocoding_fingerprint
      address.street = 'Another Street'
      expect(address.geocoding_fingerprint).not_to eq(previous)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:street) }
    it { is_expected.to validate_length_of(:street).is_at_least(2).is_at_most(150) }
    it { is_expected.to validate_presence_of(:exterior_number) }
    it 'rejects an exterior number longer than the database limit' do
      address = build(:address, exterior_number: 'A' * 21)
      expect(address).not_to be_valid
      expect(address.errors[:exterior_number]).to be_present
    end
    it { is_expected.to validate_length_of(:interior_number).is_at_most(20).allow_blank }
    it { is_expected.to validate_length_of(:reference_notes).is_at_most(200).allow_blank }
    it { is_expected.to validate_presence_of(:neighborhood) }
    it { is_expected.to validate_length_of(:neighborhood).is_at_least(2).is_at_most(100) }
    it { is_expected.to validate_presence_of(:city) }
    it { is_expected.to validate_length_of(:city).is_at_least(2).is_at_most(100) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_length_of(:state).is_at_least(2).is_at_most(100) }
    it { is_expected.to belong_to(:country) }
    it { is_expected.to validate_presence_of(:postal_code) }
    it { is_expected.to allow_value('54800').for(:postal_code) }
    it { is_expected.not_to allow_value('5480').for(:postal_code) }
    it { is_expected.not_to allow_value('ABCDE').for(:postal_code) }
    it { is_expected.to validate_presence_of(:geocoding_status) }
    it 'exposes the supported geocoding statuses' do
      expect(Address.geocoding_statuses.keys).to contain_exactly('pending', 'success', 'failed')
    end
  end

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

  describe 'enum' do
    it 'has valid geocoding statuses' do
      expect(Address.geocoding_statuses.keys)
        .to include('pending', 'success', 'failed')
    end
  end

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

  describe 'destroy' do
    it 'soft deletes record' do
      address = create(:address)

      expect { address.destroy }.to change(Address, :count).by(-1)
    end

    it 'sets deleted_at' do
      address = create(:address)

      address.destroy!

      expect(address.deleted_at).not_to be_nil
    end

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

  describe 'helpers' do
    describe '#full_address' do
      it 'builds full address string' do
        address = build(
          :address,
          street: 'Av. Reforma',
          city: 'CDMX',
          country: build(:country),
          postal_code: '06000'
        )

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

    describe 'geocoding helpers' do
      it '#geocoded? returns true when success' do
        expect(build(:address, geocoding_status: :success).geocoded?).to be true
      end

      it '#needs_geocoding? returns true when pending' do
        expect(build(:address, geocoding_status: :pending).needs_geocoding?).to be true
      end
    end
  end
end
