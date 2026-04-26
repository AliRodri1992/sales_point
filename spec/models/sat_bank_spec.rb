require 'rails_helper'

RSpec.describe SatBank, type: :model do
  subject(:sat_bank) { build(:sat_bank) }

  # =========================
  # VALIDATIONS
  # =========================
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(sat_bank).to be_valid
    end

    it 'is invalid without code' do
      sat_bank.code = nil
      expect(sat_bank).not_to be_valid
    end

    it 'is invalid with wrong code format' do
      sat_bank.code = '12'
      expect(sat_bank).not_to be_valid
    end

    it 'is invalid without name' do
      sat_bank.name = nil
      expect(sat_bank).not_to be_valid
    end

    it 'validates uniqueness of code (soft delete aware)' do
      create(:sat_bank, code: '001')
      duplicate = build(:sat_bank, code: '001')

      expect(duplicate).not_to be_valid
    end

    it 'allows duplicate if previous is soft deleted' do
      create(:sat_bank, code: '002', deleted_at: Time.current)

      new_record = build(:sat_bank, code: '002')
      expect(new_record).to be_valid
    end

    it 'is invalid if valid_to < valid_from' do
      sat_bank.valid_from = Date.current
      sat_bank.valid_to = Date.yesterday

      expect(sat_bank).not_to be_valid
    end
  end

  # =========================
  # SCOPES
  # =========================
  describe 'scopes' do
    describe '.active' do
      let!(:active)   { create(:sat_bank) }
      let!(:inactive) { create(:sat_bank, :inactive) }
      let!(:deleted)  { create(:sat_bank, :deleted) }

      it 'returns only active and not deleted records' do
        expect(described_class.active).to include(active)
        expect(described_class.active).not_to include(inactive)
        expect(described_class.active).not_to include(deleted)
      end
    end

    describe '.valid_on' do
      let!(:valid)   { create(:sat_bank) }
      let!(:expired) { create(:sat_bank, :expired) }

      it 'returns valid records for current date' do
        expect(described_class.valid_on(Date.current)).to include(valid)
        expect(described_class.valid_on(Date.current)).not_to include(expired)
      end
    end

    describe '.current' do
      let!(:current) { create(:sat_bank) }

      it 'returns active and valid records' do
        expect(described_class.current).to include(current)
      end
    end

    describe '.search' do
      let!(:bank) { create(:sat_bank, name: 'BBVA Mexico') }

      it 'returns matching records' do
        expect(described_class.search('BBVA')).to include(bank)
      end

      it 'returns all if term is blank' do
        expect(described_class.search(nil)).to match_array(described_class.all)
      end
    end
  end

  # =========================
  # INSTANCE METHODS
  # =========================
  describe 'instance methods' do
    describe '#active?' do
      it 'returns true if active' do
        expect(sat_bank.active?).to be true
      end

      it 'returns false if deleted' do
        sat_bank.deleted_at = Time.current
        expect(sat_bank.active?).to be false
      end
    end

    describe '#valid_for_date?' do
      it 'returns true when valid' do
        expect(sat_bank.valid_for_date?(Date.current)).to be true
      end

      it 'returns false when outside range' do
        expired = build(:sat_bank, :expired)
        expect(expired.valid_for_date?(Date.current)).to be false
      end
    end

    describe '#display_name' do
      it 'returns formatted string' do
        expect(sat_bank.display_name).to eq("#{sat_bank.code} - #{sat_bank.name}")
      end
    end
  end

  # =========================
  # CLASS METHODS
  # =========================
  describe 'class methods' do
    describe '.normalize_code' do
      it 'pads code with zeros' do
        expect(described_class.normalize_code('1')).to eq('001')
      end

      it 'removes non-numeric characters' do
        expect(described_class.normalize_code('A1')).to eq('001')
      end
    end

    describe '.for_cfdi' do
      it 'returns valid record' do
        bank = create(:sat_bank, code: '007')

        expect(described_class.for_cfdi('7')).to eq(bank)
      end
    end

    describe '.exists_for_cfdi?' do
      it 'returns true if exists' do
        create(:sat_bank, code: '008')

        expect(described_class.exists_for_cfdi?('8')).to be true
      end

      it 'returns false if not exists' do
        expect(described_class.exists_for_cfdi?('999')).to be false
      end
    end
  end

  # =========================
  # CALLBACKS
  # =========================
  describe 'callbacks' do
    it 'normalizes code before validation' do
      sat_bank.code = '1'
      sat_bank.valid?

      expect(sat_bank.code).to eq('001')
    end

    it 'strips name whitespace' do
      sat_bank.name = '  BBVA  '
      sat_bank.valid?

      expect(sat_bank.name).to eq('BBVA')
    end
  end
end
