require 'rails_helper'

RSpec.describe SatPaymentMethod, type: :model do
  subject { build(:sat_payment_method) }

  # =========================
  # VALIDATIONS
  # =========================
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end

    it 'is invalid without code' do
      subject.code = nil
      expect(subject).not_to be_valid
    end

    it 'is invalid with invalid code format' do
      subject.code = 'ABC'
      expect(subject).not_to be_valid
    end

    it 'is invalid without description' do
      subject.description = nil
      expect(subject).not_to be_valid
    end

    it 'validates uniqueness of code ignoring deleted_at' do
      create(:sat_payment_method, code: '01')
      duplicate = build(:sat_payment_method, code: '01')

      expect(duplicate).not_to be_valid
    end

    it 'allows duplicate code if previous is soft deleted' do
      create(:sat_payment_method, code: '01', deleted_at: Time.current)

      new_record = build(:sat_payment_method, code: '01')
      expect(new_record).to be_valid
    end

    it 'is invalid if valid_to is before valid_from' do
      subject.valid_from = Time.current
      subject.valid_to = 1.day.ago

      expect(subject).not_to be_valid
    end
  end

  # =========================
  # SCOPES
  # =========================
  describe 'scopes' do
    let!(:active_record) { create(:sat_payment_method, status: true) }
    let!(:inactive_record) { create(:sat_payment_method, status: false) }

    it 'returns only active records' do
      expect(described_class.active).to include(active_record)
      expect(described_class.active).not_to include(inactive_record)
    end

    it 'filters by valid_on date' do
      record = create(
        :sat_payment_method,
        valid_from: 2.days.ago,
        valid_to: 2.days.from_now
      )

      expect(described_class.valid_on(Time.current)).to include(record)
    end

    it 'returns current records' do
      record = create(
        :sat_payment_method,
        status: true,
        valid_from: 1.day.ago,
        valid_to: 1.day.from_now
      )

      expect(described_class.current).to include(record)
    end

    it 'searches by description' do
      record = create(:sat_payment_method, description: 'Transferencia bancaria')

      expect(described_class.search('Transferencia')).to include(record)
    end
  end

  # =========================
  # INSTANCE METHODS
  # =========================
  describe 'instance methods' do
    it 'returns true for active?' do
      subject.status = true
      subject.deleted_at = nil

      expect(subject.active?).to be true
    end

    it 'returns false for inactive?' do
      subject.status = false

      expect(subject.active?).to be false
    end

    it 'valid_for_date? works correctly' do
      subject.valid_from = 1.day.ago
      subject.valid_to = 1.day.from_now

      expect(subject.valid_for_date?(Time.current)).to be true
    end

    it 'display_name returns formatted string' do
      subject.code = '01'
      subject.description = 'Efectivo'

      expect(subject.display_name).to eq('01 - Efectivo')
    end
  end

  # =========================
  # CLASS METHODS
  # =========================
  describe 'class methods' do
    let!(:record) do
      create(
        :sat_payment_method,
        code: '01',
        status: true,
        valid_from: 1.day.ago,
        valid_to: 1.day.from_now
      )
    end

    it 'for_cfdi finds valid record' do
      expect(described_class.for_cfdi('1')).to eq(record)
    end

    it 'exists_for_cfdi? returns true if exists' do
      expect(described_class.exists_for_cfdi?('01')).to be true
    end

    it 'normalize_code formats correctly' do
      expect(described_class.normalize_code('1')).to eq('01')
    end
  end

  # =========================
  # CALLBACKS
  # =========================
  describe 'callbacks' do
    it 'normalizes code before validation' do
      record = build(:sat_payment_method, code: '1')
      record.validate

      expect(record.code).to eq('01')
    end

    it 'strips description' do
      record = build(:sat_payment_method, description: '  Test  ')
      record.validate

      expect(record.description).to eq('Test')
    end
  end
end
