# frozen_string_literal: true

module Admin
  class BranchesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch, only: %i[show edit update destroy]

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    def index
      authorize Branch
      load_branches
      @can_manage_branches = policy(Branch).create?
    end

    def show
      authorize @branch
      @can_manage_branches = policy(Branch).create?
    end

    def new
      @branch = Branch.new
      authorize @branch
      @branch.build_address
    end

    def edit
      authorize @branch
      @branch.build_address unless @branch.address
    end

    def create
      @branch = Branch.new(branch_params)
      authorize @branch

      if @branch.save
        notify_branch(current_user, @branch, 'created')
        redirect_to admin_branches_path,
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
        redirect_to admin_branches_path,
                    flash: { swal_message: t('admin.branches.updated') }
      else
        @branch.build_address unless @branch.address
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @branch
      @branch.update!(deleted_at: Time.current)
      notify_branch(current_user, @branch, 'destroyed')
      load_branches
      @can_manage_branches = policy(Branch).create?

      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.branches.destroyed') }
        format.html do
          redirect_to admin_branches_path,
                      flash: { swal_message: t('admin.branches.destroyed') }
        end
      end
    end

    private

    def set_branch
      @branch = policy_scope(Branch).find(params[:id])
    end

    def load_branches
      scope = policy_scope(Branch).includes(:address).order(:name)
      @total_count = scope.count
      @per_page = per_page_param(@total_count)
      @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
      @current_page = params[:page].to_i.clamp(1, @total_pages)
      @branches = scope.limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def per_page_param(total_count)
      return PER_PAGE if total_count <= PER_PAGE

      value = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : PER_PAGE
    end

    def branch_params
      params.expect(
        branch: [
          :name,
          :phone,
          :status,
          { address_attributes: %i[
            id street exterior_number interior_number neighborhood city state country postal_code
          ] }
        ]
      )
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
