# frozen_string_literal: true

module Admin
  class InventoriesController < ApplicationController
    include TableListingPagination
    include Admin::InventoryBranchListing

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch
    before_action :set_inventory, only: %i[update adjust]

    def index
      authorize Inventory, :index?
      load_inventory_list
    end

    def create
      @new_inventory = build_inventory
      authorize @new_inventory, :create?
      return head :forbidden if @branch.closed? || @branch.suspended?
      return redirect_inventory('created') if @new_inventory.save

      render_inventory_errors
    rescue ActiveRecord::RecordNotUnique
      @new_inventory.errors.add(:product_id, :taken)
      render_inventory_errors
    end

    def update
      authorize @inventory, :update?
      return head :forbidden if @branch.closed? || @branch.suspended?
      return redirect_inventory('updated') if @inventory.update(inventory_params.except(:product_id))

      @threshold_inventory_id = @inventory.id
      render_inventory_errors
    end

    def adjust
      authorize @inventory, :adjust?
      apply_adjustment
      redirect_inventory('adjusted')
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      restore_adjustment_errors(e)
      render_inventory_errors
    end

    private

    def set_branch
      return head :forbidden unless current_organization

      @branch = current_organization.branches.not_deleted.find(params[:branch_id])
      authorize Inventory.new(organization: current_organization, branch: @branch), :show?
    end

    def set_inventory
      @inventory = policy_scope(@branch.inventories).find(params[:id])
    end

    def build_inventory
      @branch.inventories.new(inventory_params.except(:product_id)).tap do |inventory|
        inventory.organization = current_organization
        inventory.product = current_organization.products.not_deleted.find_by(id: inventory_params[:product_id])
      end
    end

    def apply_adjustment
      Inventories::ApplyMovement.call(
        inventory: @inventory, quantity: params[:quantity], kind: 'adjustment',
        user: current_user, reference: params[:reference].to_s.strip.first(100),
        inventory_lot: adjustment_lot
      )
    end

    def adjustment_lot
      return if params[:inventory_lot_id].blank?

      @inventory.inventory_lots.find(params[:inventory_lot_id])
    end

    def redirect_inventory(action)
      redirect_to admin_branch_inventories_path(@branch), status: :see_other,
                  flash: { swal_message: t("admin.inventory.messages.#{action}") }
    end

    def render_inventory_errors
      load_inventory_list
      render :index, status: :unprocessable_content
    end

    def restore_adjustment_errors(error)
      @adjustment_inventory_id = @inventory.id
      @adjustment_value = params[:quantity]
      @adjustment_lot_id = params[:inventory_lot_id].to_s
      @adjustment_reference = params[:reference]
      if error.is_a?(ArgumentError) && error.message.match?(/lot/i)
        @adjustment_lot_error = t('admin.branch_lifecycle.inventory_lot_invalid')
      else
        @adjustment_error = quantity_error_message(error)
      end
    end

    def quantity_error_message(error)
      return t('admin.branch_lifecycle.inventory_quantity_invalid') if error.is_a?(ArgumentError)

      messages = error.record.errors[:quantity]
      messages.any? ? messages.join(', ') : t('admin.branch_lifecycle.inventory_quantity_rejected')
    end

    def inventory_params
      params.expect(inventory: %i[product_id min_stock max_stock])
    end
  end
end
