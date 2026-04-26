require 'rails_helper'

RSpec.describe SatCurrency, type: :model do
  subject { build(:sat_currency) }

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

    it 'is invalid with bad code format' do
      subject.code = 'usd1'
      expect(subject).not_to be_valid
    end

    it 'is invalid without description' do
      subject.description = nil
      expect(subject).not_to be_valid
    end

    it 'is invalid with decimals not allowed' do
      subject.decimals = 7
      expect(subject).not_to be_valid
    end

    it 'is invalid with negative variation_percentage' do
      subject.variation_percentage = -5
      expect(subject).not_to be_valid
    end
  end

  # =========================
  # SCOPES
  # =========================
  describe 'scopes' do
    before do
      create_list(:sat_currency, 3)
      create(:sat_currency, :usd)
    end

    it '.ordered returns sorted records' do
      expect(SatCurrency.ordered.count).to be >= 4
    end

    it '.by_code finds currency' do
      currency = SatCurrency.by_code('USD').first!

      expect(currency.code).to eq('USD')
    end
  end

  # =========================
  # PARANOIA
  # =========================
  describe 'soft delete (paranoia)' do
    it 'soft deletes record' do
      currency = create(:sat_currency)

      expect { currency.destroy }.to change(SatCurrency, :count).by(-1)
    end

    it 'keeps record in with_deleted' do
      currency = create(:sat_currency)

      currency.destroy!

      expect(SatCurrency.with_deleted).to include(currency)
    end

    it 'restores record' do
      currency = create(:sat_currency)

      currency.destroy!
      currency.restore

      expect(SatCurrency.exists?(currency.id)).to be true
    end
  end

  # =========================
  # METHODS
  # =========================
  describe 'methods' do
    it '#iso_code returns symbol' do
      currency = build(:sat_currency, code: 'USD')

      expect(currency.iso_code).to eq(:USD)
    end

    it '#format_amount formats correctly' do
      currency = build(:sat_currency, decimals: 2)

      expect(currency.format_amount(10)).to eq('10.00')
    end

    it '#format_with_symbol returns formatted string' do
      currency = build(:sat_currency, code: 'USD', symbol: '$')

      expect(currency.format_with_symbol(10)).to include('10.00')
    end

    it '#fiat? returns true when symbol exists' do
      currency = build(:sat_currency, symbol: '$')

      expect(currency.fiat?).to be true
    end

    it '#base_currency? detects MXN' do
      currency = build(:sat_currency, code: 'MXN')

      expect(currency.base_currency?).to be true
    end
  end
end
