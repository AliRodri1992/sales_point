# frozen_string_literal: true

module Admin
  class InventoryOverviewController < ApplicationController
    include TableListingPagination

    layout 'admin_dashboard'
    before_action :authenticate_user!

    FILTERS = %w[search branch_id status tracking sort].freeze
    SORTS = %w[product branch stock_asc stock_desc updated].freeze

    def index
      authorize Inventory, :index?
      load_branches
      load_filters

      scope = base_scope
      @summary = Inventories::Directory.summary(scope)
      @inventories = paginate_table_listing(
        ordered(filtered(scope)).includes(:branch, :product), table_key: 'inventories'
      )
    end

    private

    def load_branches
      @branches = current_organization.branches.not_deleted.order(:name)
      return if current_user.admin?

      roles = InventoryPolicy.permitted_roles(current_user, current_organization, InventoryPolicy::READ_KEYS)
      return if roles.exists?(branch_id: nil)

      @branches = @branches.where(id: roles.where.not(branch_id: nil).select(:branch_id))
    end

    def load_filters
      @filters = FILTERS.index_with { |key| params[key].to_s.strip }
      @filters['search'] = @filters['search'].first(120)
      @filters['branch_id'] = '' unless @branches.exists?(id: @filters['branch_id'])
      normalize_filter_options
    end

    def normalize_filter_options
      @filters['status'] = '' unless Inventories::Directory::STOCK_STATUSES.include?(@filters['status'])
      @filters['tracking'] = '' unless Inventories::Directory::TRACKING_MODES.include?(@filters['tracking'])
      @filters['sort'] = 'product' unless SORTS.include?(@filters['sort'])
    end

    def base_scope
      policy_scope(current_organization.inventories)
        .joins(:branch, :product)
        .where(branches: { deleted_at: nil }, products: { deleted_at: nil })
    end

    def filtered(scope)
      records = Inventories::Directory.filter(scope, @filters)
      return records if @filters['branch_id'].blank?

      records.where(branch_id: @filters['branch_id'])
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
