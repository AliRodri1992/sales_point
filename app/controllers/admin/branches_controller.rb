# frozen_string_literal: true

module Admin
  class BranchesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch, only: %i[edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    def index
      load_branches
    end

    def new
      @branch = Branch.new
      @branch.build_address
    end

    def edit
      @branch.build_address unless @branch.address
    end

    def create
      @branch = Branch.new(branch_params)

      if @branch.save
        notify_branch_change('created')
        redirect_to admin_branches_path,
                    flash: { swal_message: t('admin.branches.created') }
      else
        @branch.build_address unless @branch.address
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @branch.update(branch_params)
        notify_branch_change('updated')
        redirect_to admin_branches_path,
                    flash: { swal_message: t('admin.branches.updated') }
      else
        @branch.build_address unless @branch.address
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @branch.update!(deleted_at: Time.current)
      notify_branch_change('destroyed')
      redirect_to admin_branches_path,
                  flash: { swal_message: t('admin.branches.destroyed') }
    end

    private

    def set_branch
      @branch = Branch.where(deleted_at: nil).find(params[:id])
    end

    def load_branches
      scope = Branch.where(deleted_at: nil).includes(:address).order(:name)
      @total_count = scope.count
      @per_page = per_page_param
      @total_pages = [(@total_count / @per_page.to_f).ceil, 1].max
      @current_page = [[params[:page].to_i, 1].max, @total_pages].min
      @branches = scope.limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def per_page_param
      value = params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : PER_PAGE
    end

    def branch_params
      params.expect(
        branch: [
          :name,
          :phone,
          :status,
          address_attributes: %i[
            id street exterior_number interior_number neighborhood city state country postal_code
          ]
        ]
      )
    end

    def notify_branch_change(action)
      BranchNotification
        .with(
          action: action,
          record: @branch,
          user: current_user,
          user_name: current_user.display_name
        )
        .deliver(current_user, enqueue_job: false)

      current_user.broadcast_notifications_refresh
    end
  end
end
