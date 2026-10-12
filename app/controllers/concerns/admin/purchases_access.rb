# frozen_string_literal: true

module Admin
  module PurchasesAccess
    extend ActiveSupport::Concern

    included do
      include SupplierAuditTrail
      layout 'admin_dashboard'
      before_action :authenticate_user!
      before_action :require_purchase_organization!
    end

    private

    def require_purchase_organization!
      head :forbidden unless current_organization &&
                             current_user.organization_memberships.exists?(
                               organization_id: current_organization.id, status: :active
                             )
    end

    def load_purchase_catalogs
      @branches = current_organization.branches.not_deleted.order(:name)
      @products = current_organization.products.not_deleted.order(:name)
      @suppliers = current_organization.suppliers.available.order(:name)
      @currencies = Currency.active.order(:code)
      @offers = current_organization.supplier_products.available.includes(:product, :supplier)
    end

    def reject_purchase(error, path)
      redirect_to path, alert: error.message
    end
  end
end
