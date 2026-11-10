# frozen_string_literal: true

module Admin
  class InventoryLotsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def index
      return head :forbidden unless current_organization

      @branch = policy_scope(current_organization.branches).not_deleted.find(params[:branch_id])
      @inventory = policy_scope(@branch.inventories).find(params[:inventory_id])
      authorize @inventory, :show?
      @lots = @inventory.inventory_lots.includes(:inventory_serials, :goods_receipt_item)
                        .order(Arel.sql('expires_on ASC NULLS LAST'), :id)
    end
  end
end
