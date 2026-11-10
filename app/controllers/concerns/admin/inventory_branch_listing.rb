# frozen_string_literal: true

module Admin
  module InventoryBranchListing
    private

    def load_inventory_list
      record = Inventory.new(organization: current_organization, branch: @branch)
      @can_manage = policy(record).create?
      @can_adjust = policy(record).adjust?
      @inventory_filters = normalized_inventory_filters

      scope = policy_scope(@branch.inventories).joins(:product)
      @inventory_totals = Inventories::Directory.summary(scope)
      @inventories = paginate_table_listing(inventory_rows(scope), table_key: 'branch_inventories')
      load_recent_movements
    end

    def normalized_inventory_filters
      {
        'search' => params[:search].to_s.strip.first(120),
        'status' => Inventories::Directory::STOCK_STATUSES.include?(params[:status]) ? params[:status] : '',
        'tracking' => Inventories::Directory::TRACKING_MODES.include?(params[:tracking]) ? params[:tracking] : ''
      }
    end

    def inventory_rows(scope)
      Inventories::Directory.filter(scope, @inventory_filters)
                            .order('products.name ASC', 'inventories.id ASC')
                            .includes(:product, :inventory_lots)
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
  end
end
