# frozen_string_literal: true

module Admin
  class SupplierSchedulesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_schedule, only: %i[edit update destroy]

    def index
      @schedules = @supplier.supplier_schedules.includes(:branch).order(:weekday, :starts_at)
    end

    def new
      @schedule = @supplier.supplier_schedules.new
      load_branches
    end

    def edit
      load_branches
    end

    def create
      @schedule = @supplier.supplier_schedules.new(schedule_params)
      if @schedule.save
        redirect_to admin_supplier_schedules_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        load_branches
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @schedule.update(schedule_params)
        redirect_to admin_supplier_schedules_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        load_branches
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @schedule.destroy!
      redirect_to admin_supplier_schedules_path(@supplier), notice: t('admin.supplier_details.deleted')
    end

    private

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, action_name.in?(%w[index]) ? :show? : :update?
    end

    def set_schedule
      @schedule = @supplier.supplier_schedules.find(params[:id])
    end

    def load_branches
      @branches = current_organization.branches.not_deleted.order(:name)
    end

    def schedule_params
      params.expect(supplier_schedule: %i[branch_id kind weekday starts_at ends_at notes])
    end
  end
end
