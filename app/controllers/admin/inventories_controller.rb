# frozen_string_literal: true

module Admin
  class InventoriesController < ApplicationController
    include TableListingPagination

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch
    before_action :set_inventory, only: %i[update adjust]

    def index
      authorize Inventory, :index?
      load_inventory_list
    end

    def create
      @new_inventory = Inventory.new(organization: current_organization, branch: @branch)
      authorize @new_inventory, :create?
      return head :forbidden if @branch.closed? || @branch.suspended?

      @new_inventory.assign_attributes(inventory_params.except(:stock))
      @new_inventory.product = current_organization.products.not_deleted.find_by(id: inventory_params[:product_id])
      if @new_inventory.save
        redirect_to admin_branch_inventories_path(@branch), status: :see_other,
                    flash: { swal_message: t('admin.inventory.messages.created') }
      else
        render_inventory_errors
      end
    rescue ActiveRecord::RecordNotUnique
      @new_inventory.errors.add(:product_id, :taken)
      render_inventory_errors
    end

    def update
      authorize @inventory, :update?
      return head :forbidden if @branch.closed? || @branch.suspended?

      if @inventory.update(inventory_params.except(:product_id, :stock))
        redirect_to admin_branch_inventories_path(@branch), status: :see_other,
                    flash: { swal_message: t('admin.inventory.messages.updated') }
      else
        @threshold_inventory_id = @inventory.id
        load_inventory_list
        render :index, status: :unprocessable_content
      end
    end

    def adjust
      authorize @inventory, :adjust?
      lot = @inventory.inventory_lots.find(params[:inventory_lot_id]) if params[:inventory_lot_id].present?
      reference = params[:reference].to_s.strip.first(100)
      Inventories::ApplyMovement.call(
        inventory: @inventory, quantity: params[:quantity],
        kind: 'adjustment', user: current_user, reference:,
        inventory_lot: lot
      )
      redirect_to admin_branch_inventories_path(@branch), status: :see_other,
                  flash: { swal_message: t('admin.inventory.messages.adjusted') }
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      restore_adjustment_errors(e)
      load_inventory_list
      render :index, status: :unprocessable_content
    end

    private

    def set_branch
      return head :forbidden unless current_organization

      @branch = policy_scope(current_organization.branches).not_deleted.find(params[:branch_id])
    end

    def set_inventory
      @inventory = policy_scope(@branch.inventories).find(params[:id])
    end

    def load_inventory_list
      @can_manage = policy(Inventory.new(organization: current_organization, branch: @branch)).create?
      @can_adjust = current_user.admin? || current_user.permission?('inventory.adjust')
      @inventory_filters = {
        'search' => params[:search].to_s.strip.first(120),
        'status' => %w[out low available].include?(params[:status]) ? params[:status] : '',
        'tracking' => %w[none lot serial].include?(params[:tracking]) ? params[:tracking] : ''
      }

      scoped = policy_scope(@branch.inventories).joins(:product)
      @inventory_totals = {
        records: scoped.count,
        stock: scoped.sum(:stock),
        out: scoped.where('inventories.stock = 0').count,
        low: scoped.where('inventories.stock > 0 AND inventories.min_stock > 0 AND inventories.stock <= inventories.min_stock').count
      }
      scoped = filter_inventory(scoped)
      @inventories = paginate_table_listing(scoped.order('products.name ASC', 'inventories.id ASC')
                                                  .includes(:product, :inventory_lots), table_key: 'branch_inventories')
      load_recent_movements
    end

    def filter_inventory(scope)
      if @inventory_filters['search'].present?
        query = "%#{Product.sanitize_sql_like(@inventory_filters['search'].downcase)}%"
        scope = scope.where('LOWER(products.name) LIKE :query OR LOWER(products.code) LIKE :query OR ' \
                            'LOWER(COALESCE(products.sku, \'\')) LIKE :query', query:)
      end
      scope = scope.where(products: { tracking_mode: @inventory_filters['tracking'] }) if @inventory_filters['tracking'].present?
      case @inventory_filters['status']
      when 'out' then scope.where('inventories.stock = 0')
      when 'low' then scope.where('inventories.stock > 0 AND inventories.min_stock > 0 AND inventories.stock <= inventories.min_stock')
      when 'available' then scope.where('inventories.stock > 0 AND (inventories.min_stock = 0 OR inventories.stock > inventories.min_stock)')
      else scope
      end
    end

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
