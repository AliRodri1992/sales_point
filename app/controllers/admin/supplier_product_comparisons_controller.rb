# frozen_string_literal: true

module Admin
  class SupplierProductComparisonsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def show
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, :view_products?
      @product = current_organization.products.not_deleted.find(params[:product_id])
      @comparison = Suppliers::CostComparison.call(organization: current_organization, product: @product)
      @currency_groups = @comparison.group_by { |entry| entry[:currency] }
    end
  end
end
