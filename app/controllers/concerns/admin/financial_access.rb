# frozen_string_literal: true

module Admin
  module FinancialAccess
    extend ActiveSupport::Concern

    included do
      include SupplierAuditTrail
      include FinancialDocumentDownloads

      layout 'admin_dashboard'
      before_action :authenticate_user!
      before_action :require_financial_organization!
    end

    private

    def require_financial_organization!
      head :forbidden unless current_organization &&
                             current_user.organization_memberships.exists?(
                               organization_id: current_organization.id, status: :active
                             )
    end

    def financial_error(error, path)
      redirect_to path, alert: error.message
    end
  end
end
