# frozen_string_literal: true

module Admin
  class InventoriesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :set_branch
    before_action :set_inventory, only: %i[update adjust]

    def index
      @inventories = @branch.inventories.includes(:product).order('products.name')
    end

    def create
      product = current_organization.products.not_deleted.find(inventory_params[:product_id])
      inventory = @branch.inventories.new(inventory_params.except(:product_id))
      inventory.organization = current_organization
      inventory.product = product
      inventory.save!
      redirect_to admin_branch_inventories_path(@branch)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_branch_inventories_path(@branch), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @inventory.update!(inventory_params.except(:product_id, :stock))
      redirect_to admin_branch_inventories_path(@branch)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_branch_inventories_path(@branch), alert: e.record.errors.full_messages.to_sentence
    end

    def adjust
      Inventories::ApplyMovement.call(
        inventory: @inventory, quantity: params.require(:quantity),
        kind: 'adjustment', user: current_user, reference: params[:reference]
      )
      redirect_to admin_branch_inventories_path(@branch)
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to admin_branch_inventories_path(@branch), alert: e.message
    end

    private

    def require_organization!
      head :forbidden unless current_organization && current_user.admin?
    end

    def set_branch
      @branch = current_organization.branches.not_deleted.find(params[:branch_id])
    end

    def set_inventory
      @inventory = @branch.inventories.find(params[:id])
    end

    def inventory_params
      params.expect(inventory: %i[product_id min_stock max_stock])
    end
  end
end
