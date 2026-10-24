# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::SupplierDossierHelper, type: :helper do
  describe '#supplier_dossier_next_occurrence' do
    let(:now) { Time.zone.local(2026, 10, 16, 10, 0) }

    it 'calculates the next day of a weekly visit' do
      visit = SupplierSchedule.new(weekday: 1, starts_at: Time.zone.parse('09:00'))
      expect(helper.supplier_dossier_next_occurrence(visit, now:)).to eq(Date.new(2026, 10, 19))
    end

    it 'keeps a visit occurring later today' do
      visit = SupplierSchedule.new(weekday: 5, starts_at: Time.zone.parse('11:00'))
      expect(helper.supplier_dossier_next_occurrence(visit, now:)).to eq(Date.new(2026, 10, 16))
    end

    it 'advances to next week if the weekly visit has already passed today' do
      visit = SupplierSchedule.new(weekday: 5, starts_at: Time.zone.parse('08:00'))
      expect(helper.supplier_dossier_next_occurrence(visit, now:)).to eq(Date.new(2026, 10, 23))
    end

    it 'uses the supplier organization time when UTC has already reached tomorrow' do
      organization = create(:organization)
      create(:organization_setting, organization:, timezone: 'America/Mexico_City')
      supplier = create(:supplier, organization:)
      branch = create(:branch, organization:)
      schedule = supplier.supplier_schedules.create!(
        branch:, kind: 'visit', weekday: 5, starts_at: '21:00', ends_at: '22:00'
      )

      expect(helper.supplier_dossier_next_occurrence(schedule, now: Time.utc(2026, 10, 17, 2)))
        .to eq(Date.new(2026, 10, 16))
    end
    it 'skips weekly occurrences disabled by a supplier-specific calendar exception' do
      organization = create(:organization)
      supplier = create(:supplier, organization:)
      branch = create(:branch, organization:)
      schedule = supplier.supplier_schedules.create!(
        branch:, kind: 'visit', weekday: 5, starts_at: '11:00', ends_at: '12:00'
      )
      supplier.supplier_schedule_exceptions.create!(
        supplier_schedule: schedule, branch:, starts_on: Date.new(2026, 10, 16),
        reason: 'suspension'
      )

      expect(helper.supplier_dossier_next_occurrence(schedule, now:)).to eq(Date.new(2026, 10, 23))
    end

    it 'uses the default timezone when a saved supplier has no active timezone configuration' do
      organization = create(:organization)
      supplier = create(:supplier, organization:)
      branch = create(:branch, organization:)
      schedule = supplier.supplier_schedules.create!(
        branch:, kind: 'visit', weekday: 5, starts_at: '11:00', ends_at: '12:00'
      )

      expect(helper.supplier_dossier_next_occurrence(schedule, now:)).to eq(Date.new(2026, 10, 16))
    end

  end
end
