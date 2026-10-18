# frozen_string_literal: true

# Preserve manually edited or archived demonstration addresses and schedules.
module SupplierDossierUniqueness
  def self.address_exists?(supplier, index, reference)
    existing = supplier.addresses.with_deleted
    existing.exists?(reference_notes: reference) ||
      existing.exists?(street: "Avenida Ejemplo #{index + 1}", exterior_number: (100 + index).to_s)
  end

  def self.schedule_exists?(supplier, attributes, notes)
    existing = supplier.supplier_schedules
    slot = attributes.slice(:branch, :kind, :weekday, :starts_at)
    existing.exists?(notes:) || existing.exists?(slot)
  end
end
