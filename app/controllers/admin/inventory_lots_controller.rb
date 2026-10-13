# frozen_string_literal: true

module Admin
  class InventoryLotsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def index
      return head :forbidden unless current_organization && current_user.admin?

      @branch = current_organization.branches.not_deleted.find(params[:branch_id])
      @inventory = @branch.inventories.find(params[:inventory_id])
      @lots = @inventory.inventory_lots.includes(:inventory_serials, :goods_receipt_item)
                        .order(Arel.sql('expires_on ASC NULLS LAST'), :id)
    end
  end
end
