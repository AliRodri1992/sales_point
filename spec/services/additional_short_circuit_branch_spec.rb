# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tenant and financial short-circuit decisions' do
  describe Onboarding::CompanyUpdater do
    let(:settings) { double('settings', assign_attributes: nil, save!: true, errors: double(add: nil)) }
    let(:organization) do
      double('organization', organization_settings: [settings], assign_attributes: nil, save!: true)
    end
    let(:parameters) do
      ActionController::Parameters.new(
        organization: {
          name: 'Store', tax_id: 'AAA010101AAA', business_sector: 'retail',
          base_currency_id: 1, timezone: 'America/Mexico_City'
        }
      )
    end
    let(:currency) { double('currency') }

    it 'stops if the organization has no settings to update' do
      allow(organization).to receive(:organization_settings).and_return([])
      expect(described_class.call(organization, parameters)).to be(false)
    end

    it 'rejects a base currency not in the active catalog' do
      allow(Currency).to receive(:active).and_return(double(find_by: nil))
      expect(described_class.call(organization, parameters, settings:)).to be(false)
      expect(settings.errors).to have_received(:add).with(:base_currency, :invalid)
    end

    it 'stops when organization update validation fails' do
      allow(Currency).to receive(:active).and_return(double(find_by: currency))
      allow(organization).to receive(:save!).and_return(false)
      expect(described_class.call(organization, parameters, settings:)).to be(false)
    end

    it 'stops if its organization settings cannot be saved' do
      allow(Currency).to receive(:active).and_return(double(find_by: currency))
      allow(settings).to receive(:save!).and_return(false)
      expect(described_class.call(organization, parameters, settings:)).to be(false)
    end

    it 'persists company and timezone settings when both updates succeed' do
      allow(Currency).to receive(:active).and_return(double(find_by: currency))
      expect(described_class.call(organization, parameters, settings:)).to be(true)
      expect(organization).to have_received(:save!).with(context: :onboardingstep1)
      expect(settings).to have_received(:assign_attributes).with(
        base_currency: currency, timezone: 'America/Mexico_City'
      )
    end
  end

  describe Admin::SuppliersFiltering do
    let(:controller) { Admin::SuppliersController.new }
    let(:scope) { double('supplier scope') }

    it 'ignores numeric filters for disallowed SQL field names' do
      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(unknown_min: 10)
      )
      expect(controller.send(:apply_numeric_bound, scope, 'unknown', 'min')).to eq(scope)
    end

    it 'ignores date filters for disallowed SQL field names' do
      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(unknown_from: '2026-10-14')
      )
      expect(controller.send(:apply_date_bound, scope, 'unknown', 'from')).to eq(scope)
    end

    it 'refuses fractional credit days rather than silently rounding' do
      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(credit_days_min: '1.5')
      )
      expect(controller.send(:apply_numeric_bound, scope, 'credit_days', 'min')).to eq(scope)
    end

    it 'accepts a matching fiscal regime from the loaded catalog' do
      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(sat_fiscal_regime_id: '601')
      )
      controller.instance_variable_set(:@supplier_regimes, [double(id: 601)])
      expect(controller.send(:valid_regime_filter?)).to be(true)
    end

    it 'rejects nonmatching fiscal regimes from an otherwise valid ID' do
      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(sat_fiscal_regime_id: '602')
      )
      controller.instance_variable_set(:@supplier_regimes, [double(id: 601)])
      expect(controller.send(:valid_regime_filter?)).to be(false)
    end
  end

  describe SupplierCreditNote do
    let(:organization) { create(:organization) }
    let(:supplier) { create(:supplier, organization:) }
    let(:actor) { create(:user) }
    let(:credit) do
      described_class.new(
        organization:, supplier:, currency: supplier.currency, created_by: actor,
        issued_on: Date.current, total: 50
      )
    end

    it 'rejects a supplier belonging to a different organization' do
      credit.supplier = create(:supplier, organization: create(:organization))
      expect(credit).not_to be_valid
      expect(credit.errors.details[:supplier]).to include(hash_including(error: :invalid))
    end

    it 'rejects a linked invoice from another supplier' do
      other_supplier = create(:supplier, organization:)
      credit.supplier_invoice = SupplierInvoice.create!(
        organization:, supplier: other_supplier, currency: other_supplier.currency,
        created_by: actor, subtotal: 20, total: 20,
        issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow
      )
      expect(credit).not_to be_valid
      expect(credit.errors.details[:supplier_invoice]).to include(hash_including(error: :invalid))
    end

    it 'accepts a linked invoice for the same organization and supplier' do
      credit.supplier_invoice = SupplierInvoice.create!(
        organization:, supplier:, currency: supplier.currency,
        created_by: actor, subtotal: 20, total: 20,
        issued_on: Date.current, received_on: Date.current, due_on: Date.tomorrow
      )
      expect(credit).to be_valid
    end

    it 'normalizes optional credit UUID values to uppercase' do
      credit.uuid = '  aabb-1234  '
      credit.valid?
      expect(credit.uuid).to eq('AABB-1234')
    end

    it 'rejects zero credit balances' do
      credit.total = 0
      expect(credit).not_to be_valid
    end
  end

  describe 'recoverable duplicate index conflicts' do
    it 'retains the soft-deletion date of supplier visits when restore races' do
      supplier = create(:supplier)
      branch = create(:branch, organization: supplier.organization)
      schedule = SupplierSchedule.create!(
        supplier:, branch:, kind: 'visit', weekday: 1, starts_at: '09:00'
      )
      schedule.update!(deleted_at: Time.current)
      allow(schedule).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
      expect(schedule.restore_safely).to be(false)
      expect(schedule.deleted_at).to be_present
    end

    it 'retains the soft-deletion date of organization contacts when restore races' do
      record = create(:contact, :deleted)
      allow(record).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
      expect(record.restore_safely).to be(false)
      expect(record.deleted_at).to be_present
    end

    it 'retains the soft-deletion date of addresses when restore races' do
      record = create(:address, :deleted)
      allow(record).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
      expect(record.restore_safely).to be(false)
      expect(record.deleted_at).to be_present
    end
  end
end
