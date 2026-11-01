# frozen_string_literal: true

module SupplierAuditTrail
  extend ActiveSupport::Concern

  included do
    around_action :with_supplier_audit_actor
  end

  private

  def with_supplier_audit_actor(&)
    PaperTrail.request(whodunnit: current_user&.id&.to_s, &)
  end
end
