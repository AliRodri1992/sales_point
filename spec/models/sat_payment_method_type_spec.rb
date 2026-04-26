require 'rails_helper'

RSpec.describe SatPaymentMethodType, type: :model do
  subject { build(:sat_payment_method_type) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end

    it 'is invalid without code' do
      subject.code = nil
      expect(subject).not_to be_valid
    end

    it 'is invalid with invalid code' do
      subject.code = 'XXX'
      expect(subject).not_to be_valid
    end

    it 'is invalid without description' do
      subject.description = nil
      expect(subject).not_to be_valid
    end

    it 'validates uniqueness of code (ignoring deleted_at)' do
      create(:sat_payment_method_type, code: 'PUE')

      duplicate = build(:sat_payment_method_type, code: 'PUE')
      expect(duplicate).not_to be_valid
    end

    it 'allows same code if previous record is soft deleted' do
      record = create(:sat_payment_method_type, code: 'PUE')
      record.update(deleted_at: Time.current)

      new_record = build(:sat_payment_method_type, code: 'PUE')
      expect(new_record).to be_valid
    end

    it 'is invalid if valid_to is less than valid_from' do
      subject.valid_from = Date.current
      subject.valid_to = Date.yesterday

      expect(subject).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_record) { create(:sat_payment_method_type, status: true) }
    let!(:inactive_record) { create(:sat_payment_method_type, status: false) }

    describe '.active' do
      it 'returns only active records' do
        expect(described_class.active).to include(active_record)
        expect(described_class.active).not_to include(inactive_record)
      end
    end

    describe '.valid_on' do
      let!(:valid_record) do
        create(
          :sat_payment_method_type,
          valid_from: Date.yesterday,
          valid_to: Date.tomorrow
        )
      end

      let!(:invalid_record) do
        create(
          :sat_payment_method_type,
          valid_from: Date.tomorrow,
          valid_to: Date.tomorrow + 5.days
        )
      end

      it 'returns records valid on given date' do
        expect(described_class.valid_on(Date.current)).to include(valid_record)
        expect(described_class.valid_on(Date.current)).not_to include(invalid_record)
      end
    end

    describe '.current' do
      it 'returns active and valid records' do
        record = create(
          :sat_payment_method_type,
          status: true,
          valid_from: Date.yesterday,
          valid_to: Date.tomorrow
        )

        expect(described_class.current).to include(record)
      end
    end
  end

  describe 'instance methods' do
    describe '#pue?' do
      it 'returns true if code is PUE' do
        record = build(:sat_payment_method_type, code: 'PUE')
        expect(record.pue?).to be true
      end
    end

    describe '#ppd?' do
      it 'returns true if code is PPD' do
        record = build(:sat_payment_method_type, code: 'PPD')
        expect(record.ppd?).to be true
      end
    end

    describe '#active?' do
      it 'returns true if status is true and not deleted' do
        record = build(:sat_payment_method_type, status: true, deleted_at: nil)
        expect(record.active?).to be true
      end

      it 'returns false if deleted' do
        record = build(:sat_payment_method_type, status: true, deleted_at: Time.current)
        expect(record.active?).to be false
      end
    end

    describe '#valid_for_date?' do
      it 'returns true if date is within range' do
        record = build(
          :sat_payment_method_type,
          valid_from: Date.yesterday,
          valid_to: Date.tomorrow
        )

        expect(record.valid_for_date?(Date.current)).to be true
      end

      it 'returns false if date is outside range' do
        record = build(
          :sat_payment_method_type,
          valid_from: Date.tomorrow,
          valid_to: Date.tomorrow + 5.days
        )

        expect(record.valid_for_date?(Date.current)).to be false
      end
    end
  end

  describe '.for_cfdi' do
    it 'returns correct record for given code and date' do
      record = create(
        :sat_payment_method_type,
        code: 'PUE',
        valid_from: Date.yesterday,
        valid_to: Date.tomorrow
      )

      result = described_class.for_cfdi('PUE', Date.current)

      expect(result).to eq(record)
    end
  end

  describe '.exists_for_cfdi?' do
    it 'returns true if record exists' do
      create(
        :sat_payment_method_type,
        code: 'PPD',
        valid_from: Date.yesterday,
        valid_to: Date.tomorrow
      )

      expect(described_class.exists_for_cfdi?('PPD')).to be true
    end

    it 'returns false if record does not exist' do
      expect(described_class.exists_for_cfdi?('PUE')).to be false
    end
  end

  describe 'callbacks' do
    it 'normalizes code to uppercase' do
      record = build(:sat_payment_method_type, code: 'pue')
      record.valid?
      expect(record.code).to eq('PUE')
    end

    it 'strips description' do
      record = build(:sat_payment_method_type, description: '  Test  ')
      record.valid?
      expect(record.description).to eq('Test')
    end
  end
end
