# frozen_string_literal: true

# Deterministic example events; archived records count towards the seed quota so they
# are never recreated or reset when the seed task runs again.
module SupplierCalendarEvents
  TITLES = [
    'Visita de seguimiento', 'Pedido de reposición', 'Reparto programado',
    'Capacitación especial', 'Inventario y revisión'
  ].freeze

  def self.seed!(supplier:, branches:)
    return if branches.empty? || supplier.supplier_events.with_deleted.count >= TITLES.size

    TITLES.each_with_index { |title, index| seed_one(supplier, branches, title, index) }
  end

  def self.seed_one(supplier, branches, title, index)
    marker = "DEMO-EVENTO-#{index + 1}"
    return if supplier.supplier_events.with_deleted.exists?(notes: marker)

    date = Date.new(2026, 10, 24) + index
    starts_at = Time.zone.local(date.year, date.month, date.day, 9)
    supplier.supplier_events.create!(event_attributes(branches, title, index, starts_at, marker))
  end

  def self.event_attributes(branches, title, index, starts_at, marker)
    {
      branch: branches[index % branches.size], title:,
      kind: SupplierEvent::KINDS[index % SupplierEvent::KINDS.size],
      starts_at:, ends_at: starts_at + (index == 3 ? 2.days : 2.hours),
      all_day: index == 3, status: index == 4 ? 'completed' : 'scheduled', notes: marker
    }
  end
end
