# frozen_string_literal: true

module Admin
  class InventoryOverviewController < ApplicationController
    include TableListingPagination

    layout 'admin_dashboard'
    before_action :authenticate_user!

    FILTERS = %w[search branch_id status tracking sort].freeze
    STOCK_STATUSES = %w[available low out].freeze
    TRACKING = %w[none lot serial].freeze
    SORTS = %w[product branch stock_asc stock_desc updated].freeze

    def index
      authorize Inventory, :index?
      @branches = current_organization.branches.not_deleted.order(:name)
      unless current_user.admin?
        roles = InventoryPolicy.permitted_roles(current_user, current_organization, InventoryPolicy::READ_KEYS)
        @branches = @branches.where(id: roles.where.not(branch_id: nil).select(:branch_id)) unless roles.where(branch_id: nil).exists?
      end
      @filters = FILTERS.index_with { |key| params[key].to_s.strip }
      @filters['search'] = @filters['search'].first(120)
      @filters['branch_id'] = '' unless @branches.exists?(id: @filters['branch_id'])
      @filters['status'] = '' unless STOCK_STATUSES.include?(@filters['status'])
      @filters['tracking'] = '' unless TRACKING.include?(@filters['tracking'])
      @filters['sort'] = 'product' unless SORTS.include?(@filters['sort'])

      base = policy_scope(current_organization.inventories).joins(:branch, :product)
                         .where(branches: { deleted_at: nil }, products: { deleted_at: nil })
      load_metrics(base)
      @inventories = paginate_table_listing(ordered(filtered(base)).includes(:branch, :product),
                                           table_key: 'inventories')
    end

    private

    def load_metrics(scope)
      @summary = {
        records: scope.count,
        stock: scope.sum(:stock),
        out: scope.where('inventories.stock = 0').count,
        low: scope.where('inventories.stock > 0 AND inventories.min_stock > 0 AND inventories.stock <= inventories.min_stock').count
      }
    end

    def filtered(scope)
      if @filters['search'].present?
        query = "%#{Product.sanitize_sql_like(@filters['search'].downcase)}%"
        scope = scope.where(
          'LOWER(products.name) LIKE :query OR LOWER(products.code) LIKE :query OR ' \
          'LOWER(COALESCE(products.sku, \'\')) LIKE :query OR LOWER(COALESCE(products.barcode, \'\')) LIKE :query',
          query:
        )
      end
      scope = scope.where(branch_id: @filters['branch_id']) if @filters['branch_id'].present?
      scope = scope.where(products: { tracking_mode: @filters['tracking'] }) if @filters['tracking'].present?
      case @filters['status']
      when 'out' then scope.where('inventories.stock = 0')
      when 'low' then scope.where('inventories.stock > 0 AND inventories.min_stock > 0 AND inventories.stock <= inventories.min_stock')
      when 'available' then scope.where('inventories.stock > 0 AND (inventories.min_stock = 0 OR inventories.stock > inventories.min_stock)')
      else scope
      end
    end

    def ordered(scope)
      order = case @filters['sort']
              when 'branch' then 'branches.name ASC, products.name ASC'
              when 'stock_asc' then 'inventories.stock ASC, products.name ASC'
              when 'stock_desc' then 'inventories.stock DESC, products.name ASC'
              when 'updated' then 'inventories.updated_at DESC'
              else 'products.name ASC, branches.name ASC'
              end
      scope.order(Arel.sql(order)).order('inventories.id ASC')
    end
  end
end
