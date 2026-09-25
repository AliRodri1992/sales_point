# frozen_string_literal: true

module Admin
  class BranchesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch, only: %i[update destroy]

    def index
      @branches = Branch.where(deleted_at: nil).includes(:address).order(:name)
      @branch = Branch.new
      @branch.build_address
    end

    def create
      @branch = Branch.new(branch_params)

      if @branch.save
        notify_branch_change('created')
        redirect_to admin_branches_path,
                    flash: { swal_message: t('admin.branches.created') }
      else
        prepare_index
        render :index, status: :unprocessable_content
      end
    end

    def update
      if @branch.update(branch_params)
        notify_branch_change('updated')
        redirect_to admin_branches_path,
                    flash: { swal_message: t('admin.branches.updated') }
      else
        prepare_index
        render :index, status: :unprocessable_content
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

    def prepare_index
      @branches = Branch.where(deleted_at: nil).includes(:address).order(:name)
      @branch.build_address unless @branch.address
    end

    def branch_params
      params.expect(
        branch: [
          :name,
          :phone,
          :status,
          address_attributes: %i[
            id
            street
            exterior_number
            interior_number
            neighborhood
            city
            state
            country
            postal_code
          ]
        ]
      )
    end

    def notify_branch_change(action)
      BranchNotification
        .with(action: action, record: @branch, user: current_user)
        .deliver(current_user, enqueue_job: false)

      current_user.broadcast_notifications_refresh
    end
  end
end
