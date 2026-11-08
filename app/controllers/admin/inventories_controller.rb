# frozen_string_literal: true

module Admin
  class InventoriesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_organization!
    before_action :set_branch
    before_action :set_inventory, only: %i[update adjust]

    def index
      load_inventory_list
    end

    def load_inventory_list
      @inventories = @branch.inventories.includes(:product).order('products.name')
      load_recent_movements
    end

    # SQL window function limits movements per inventory, not per entire branch.
    def load_recent_movements
      ids = @inventories.map(&:id)
      @recent_movements_by_inventory = {}
      return if ids.empty?

      ranked = InventoryMovement.where(inventory_id: ids)
                                .select('inventory_movements.*', Arel.sql(<<~SQL.squish))
                                  ROW_NUMBER() OVER (
                                    PARTITION BY inventory_id ORDER BY created_at DESC, id DESC
                                  ) AS movement_rank
                                SQL
      @recent_movements_by_inventory = InventoryMovement
                                       .from("(#{ranked.to_sql}) inventory_movements")
                                       .where('movement_rank <= 5')
                                       .order(:inventory_id, created_at: :desc, id: :desc)
                                       .to_a.group_by(&:inventory_id)
    end

    def create
      return head :forbidden if @branch.closed? || @branch.suspended?

      @new_inventory = build_inventory
      if @new_inventory.save
        redirect_to admin_branch_inventories_path(@branch), status: :see_other
      else
        render_inventory_errors
      end
    rescue ActiveRecord::RecordInvalid => e
      @new_inventory = e.record
      render_inventory_errors
    end

    def build_inventory
      product = current_organization.products.not_deleted.find_by(id: inventory_params[:product_id])
      @branch.inventories.new(inventory_params.except(:product_id)).tap do |inventory|
        inventory.organization = current_organization
        inventory.product = product
      end
    end

    def render_inventory_errors
      load_inventory_list
      render :index, status: :unprocessable_content
    end

    def update
      return head :forbidden if @branch.closed?

      @inventory.update!(inventory_params.except(:product_id, :stock))
      redirect_to admin_branch_inventories_path(@branch)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_branch_inventories_path(@branch), alert: e.record.errors.full_messages.to_sentence
    end

    def adjust
      Inventories::ApplyMovement.call(
        inventory: @inventory, quantity: params[:quantity],
        kind: 'adjustment', user: current_user, reference: params[:reference]
      )
      redirect_to admin_branch_inventories_path(@branch), status: :see_other
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      @adjustment_inventory_id = @inventory.id
      @adjustment_value = params[:quantity]
      @adjustment_error = quantity_error_message(e)
      load_inventory_list
      render :index, status: :unprocessable_content
    end

    def quantity_error_message(error)
      return t('admin.branch_lifecycle.inventory_quantity_invalid') if error.is_a?(ArgumentError)

      messages = error.record.errors[:quantity]
      messages.any? ? messages.join(', ') : t('admin.branch_lifecycle.inventory_quantity_rejected')
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
