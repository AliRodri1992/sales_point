# frozen_string_literal: true

module Admin
  class SupplierSchedulesController < ApplicationController
    include SupplierAuditTrail

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_schedule, only: %i[edit update destroy]

    def index
      @schedules = @supplier.supplier_schedules.not_deleted.includes(:branch).order(:weekday, :starts_at)
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
        notify_schedule('schedule_created')
        redirect_to admin_supplier_schedules_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        load_branches
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @schedule.update(schedule_params)
        notify_schedule('schedule_updated')
        redirect_to admin_supplier_schedules_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        load_branches
        render :edit, status: :unprocessable_content
      end
    end

    def restore
      @schedule = @supplier.supplier_schedules.with_deleted.where.not(deleted_at: nil).find(params[:id])
      if @schedule.restore_safely
        notify_schedule('schedule_restored')
        redirect_to admin_supplier_schedules_path(@supplier), notice: t('admin.supplier_details.saved')
      else
        redirect_to admin_supplier_schedules_path(@supplier), alert: @schedule.errors.full_messages.to_sentence
      end
    end

    def destroy
      @schedule.update!(deleted_at: Time.current)
      notify_schedule('schedule_deleted')
      redirect_to admin_supplier_schedules_path(@supplier), notice: t('admin.supplier_details.deleted')
    end

    private

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, action_name.in?(%w[index]) ? :view_schedules? : :manage_schedules?
    end

    def set_schedule
      @schedule = @supplier.supplier_schedules.not_deleted.find(params[:id])
    end

    def load_branches
      @branches = current_organization.branches.not_deleted.order(:name)
    end

    def notify_schedule(action)
      Suppliers::NotifyService.call(action:, supplier: @supplier, user: current_user, subject: @schedule)
    end

    def schedule_params
      params.expect(supplier_schedule: %i[branch_id kind weekday starts_at ends_at notes])
    end
  end
end
