# frozen_string_literal: true

module Admin
  class BranchesController < ApplicationController
    include Admin::BranchFilters
    include Admin::BranchesListing
    include Admin::BranchForm
    include Admin::BranchTransitions
    include Admin::BranchSupport
    include Admin::BranchTerminals

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch, only: %i[show edit update destroy transition_status add_terminal change_terminal]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden
    rescue_from ActiveRecord::RecordNotUnique, with: :branch_identifier_taken
    helper_method :branch_directory_parameters, :branch_directory_path

    PER_PAGE = 10
    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS
    SORTABLE_COLUMNS = %w[
      branches.name
      addresses.street
      branches.operational_status
      branches.code
      branches.created_at
    ].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    def select
      branch = available_branches.find(params[:id])
      session[:current_branch_id] = branch.id

      redirect_back_or_to(admin_dashboard_path)
    end

    def index
      authorize Branch
      load_branches
      @can_manage_branches = current_organization.present? && policy(Branch).create?
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      authorize @branch
      load_branch_detail
    end

    def new
      @branch = Branch.new(organization: current_organization)
      authorize @branch
      @branch.build_address
    end

    def edit
      authorize @branch
      @branch.build_address unless @branch.address
    end

    def create
      @branch = Branch.new(branch_params)
      @branch.organization ||= current_organization
      raise Pundit::NotAuthorizedError unless current_organization

      authorize @branch

      if @branch.save
        notify_branch(current_user, @branch, 'created')
        redirect_to branch_directory_path,
                    flash: { swal_message: t('admin.branches.created') }
      else
        @branch.build_address unless @branch.address
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @branch

      if @branch.update(branch_params)
        notify_branch(current_user, @branch, 'updated')
        redirect_to branch_directory_path,
                    flash: { swal_message: t('admin.branches.updated') }
      else
        @branch.build_address unless @branch.address
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @branch
      unless @branch.update(deleted_at: Time.current)
        return redirect_to admin_branch_path(@branch, branch_directory_parameters),
                           alert: @branch.errors.full_messages.to_sentence, status: :see_other
      end
      render_destroyed_branch
    end

    private

    def load_branch_detail
      @branch_team_count = Branch.team_assignments(current_organization)
                                 .where(branch_id: @branch.id).distinct.count(:user_id)
      return unless policy(@branch).manage?

      @branch_operation_counts = { products: @branch.inventories.distinct.count(:product_id),
                                   terminals: @branch.terminals.count }
    end

    def set_branch
      @branch = policy_scope(organization_branches).find(params[:id])
    end

    def forbidden
      head :forbidden
    end
  end
end
