# frozen_string_literal: true

module Admin
  class BranchesController < ApplicationController
    include Admin::BranchFilters
    include Admin::BranchesListing
    include Admin::BranchForm
    include Admin::BranchTransitions
    include Admin::BranchSupport
    include Admin::BranchTerminals
    include Admin::BranchAudits

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_paper_trail_whodunnit
    before_action :set_branch, except: %i[index new create select postal_suggestions]

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
      @branch.lifecycle_created_by = current_user
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
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_branch_path(@branch, branch_directory_parameters),
                  alert: e.record.errors.full_messages.to_sentence, status: :see_other
    end

    def destroy
      authorize @branch
      unless @branch.update(deleted_at: Time.current)
        return redirect_to admin_branch_path(@branch, branch_directory_parameters),
                           alert: @branch.errors.full_messages.to_sentence, status: :see_other
      end
      render_destroyed_branch
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_branch_path(@branch, branch_directory_parameters),
                  alert: e.record.errors.full_messages.to_sentence, status: :see_other
    end

    private

    def load_branch_detail
      @branch_team_count = Branch.team_assignments(current_organization)
                                 .where(branch_id: @branch.id).distinct.count(:user_id)
      requirements = Branches::LifecycleRequirements.new(branch: @branch, actor: current_user)
      if @branch.preparing? || @branch.suspended?
        @branch_activation_requirements = requirements.activation
      end
      return unless policy(@branch).manage?

      @branch_transition_blockers = branch_transition_blockers_for_view(requirements)
      @branch_operation_counts = { products: @branch.inventories.distinct.count(:product_id),
                                   terminals: @branch.terminals.count }
      load_branch_change_events
    end

    def branch_transition_blockers_for_view(requirements)
      allowed = Branches::TransitionStatus::ALLOWED.fetch(@branch.operational_status, [])
      allowed.index_with do |target|
        if target == 'active' && @branch_activation_requirements
          @branch_activation_requirements.reject { |_key, ready| ready }.keys
        else
          requirements.blockers_for(target)
        end
      end
    end

    def set_branch
      @branch = policy_scope(organization_branches).find(params[:id])
    end

    def forbidden
      head :forbidden
    end
  end
end
