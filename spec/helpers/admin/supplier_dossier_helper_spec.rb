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
  end
end
