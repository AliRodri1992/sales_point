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

    anchor = Date.new(2026, 10, 24)
    TITLES.each_with_index do |title, index|
      marker = "DEMO-EVENTO-#{index + 1}"
      next if supplier.supplier_events.with_deleted.exists?(notes: marker)

      date = anchor + index
      starts_at = Time.zone.local(date.year, date.month, date.day, 9)
      supplier.supplier_events.create!(
        branch: branches[index % branches.size], title:,
        kind: SupplierEvent::KINDS[index % SupplierEvent::KINDS.size],
        starts_at:, ends_at: starts_at + (index == 3 ? 2.days : 2.hours),
        all_day: index == 3, status: index == 4 ? 'completed' : 'scheduled',
        notes: marker
      )
    end
  end
end
