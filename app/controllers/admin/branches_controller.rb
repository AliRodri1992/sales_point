# frozen_string_literal: true

module Admin
  class BranchesController < ApplicationController
    include Admin::BranchFilters
    include Admin::BranchesListing
    include Admin::BranchForm

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch, only: %i[show edit update destroy transition_status]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden
    rescue_from ActiveRecord::RecordNotUnique, with: :branch_identifier_taken
    helper_method :branch_directory_parameters, :branch_directory_path

    PER_PAGE = 10
    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS
    SORTABLE_COLUMNS = %w[
      branches.name
      addresses.street
      branches.status
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

    def postal_suggestions
      raise Pundit::NotAuthorizedError unless current_organization

      authorize Branch.new(organization: current_organization), :create?
      return head :unprocessable_content unless valid_postal_lookup_params?

      suggestion = Suppliers::MexicanPostalLookup.new(params[:postal_code]).call
      return head :service_unavailable unless suggestion

      response.headers['Cache-Control'] = 'private, no-store'
      render json: suggestion
    end

    def show
      authorize @branch
      @branch_team_count = Branch.team_assignments(current_organization)
                                 .where(branch_id: @branch.id).distinct.count(:user_id)
      return unless policy(@branch).update?

      @branch_operation_counts = { products: @branch.inventories.distinct.count(:product_id),
                                   terminals: @branch.terminals.count }
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

    def transition_status
      authorize @branch, :update?
      Branches::TransitionStatus.call(branch: @branch, actor: current_user,
                                      to: params[:to_status], reason: params[:reason])
      redirect_to admin_branch_path(@branch, branch_directory_parameters),
                  flash: { swal_message: t('admin.branch_lifecycle.changed') }, status: :see_other
    rescue Branches::TransitionStatus::InvalidTransition => e
      redirect_to admin_branch_path(@branch, branch_directory_parameters),
                  alert: e.message, status: :see_other
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
    end

    private

    def valid_postal_lookup_params?
      params[:country] == 'MX' && /\A\d{5}\z/.match?(params[:postal_code].to_s)
    end

    def render_destroyed_branch
      notify_branch(current_user, @branch, 'destroyed')
      load_branches
      @can_manage_branches = current_organization.present? && policy(Branch).create?

      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.branches.destroyed') }
        format.html do
          redirect_to branch_directory_path,
                      flash: { swal_message: t('admin.branches.destroyed') }
        end
      end
    end

    def set_branch
      @branch = policy_scope(organization_branches).find(params[:id])
    end

    def notify_branch(user, branch, action)
      BranchNotification
        .with(action: action, record: branch, user:)
        .deliver(user, enqueue_job: false)

      user.broadcast_notifications_refresh
    end

    def forbidden
      head :forbidden
    end
  end
end
