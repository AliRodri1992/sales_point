# frozen_string_literal: true

module SupplierAuditTrail
  extend ActiveSupport::Concern

  included do
    around_action :with_supplier_audit_actor
  end

  private

  def with_supplier_audit_actor(&action)
    PaperTrail.request(whodunnit: current_user&.id&.to_s, &action)
  end
end
