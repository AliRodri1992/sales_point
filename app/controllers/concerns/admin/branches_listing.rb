# frozen_string_literal: true

module Admin
  module BranchesListing
    FILTER_KEYS = %w[search status country_id state city contact team created_from created_to].freeze
    NAVIGATION_KEYS = (FILTER_KEYS + %w[sort direction per_page page]).freeze

    private

    def load_branches
      scope = policy_scope(organization_branches).left_joins(:address)
      @branch_counts = scope.group('branches.status').count
      normalize_branch_filters(scope)
      paginate_branches(filter_branches(scope))
    end

    def paginate_branches(scope)
      @total_count = scope.count
      @per_page = table_page_size_for('branches')
      @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
      @current_page = params[:page].to_s.to_i.clamp(1, @total_pages)
      @branches = branch_page(apply_sorting(scope)).includes(:phones, address: :country)
      load_branch_team_counts
    end

    def load_branch_team_counts
      @branch_team_counts = Branch.team_assignments(current_organization).where(branch_id: @branches.map(&:id))
                                  .group(:branch_id).distinct.count(:user_id)
    end

    def organization_branches
      Branch.where(organization_id: current_organization&.id)
    end

    def apply_sorting(scope)
      columns = Admin::BranchesController::SORTABLE_COLUMNS
      sort_column = columns.include?(params[:sort]) ? params[:sort] : 'branches.name'
      directions = Admin::BranchesController::SORT_DIRECTIONS
      sort_direction = directions.include?(params[:direction]) ? params[:direction] : 'asc'
      scope.order(sort_column => sort_direction).order('branches.id' => :asc)
    end

    def branch_page(scope)
      scope.limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def branch_directory_parameters
      request.query_parameters.slice(*NAVIGATION_KEYS)
    end

    def branch_directory_path
      admin_branches_path(branch_directory_parameters)
    end
  end
end
