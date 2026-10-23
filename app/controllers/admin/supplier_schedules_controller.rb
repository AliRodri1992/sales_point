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
      load_exceptions
      load_branches
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
      if save_schedule
        notify_schedule('schedule_created')
        redirect_to schedule_destination, notice: t('admin.supplier_details.saved')
      else
        load_branches
        render :new, status: :unprocessable_content
      end
    end

    def update
      @schedule.assign_attributes(schedule_params)
      if save_schedule
        notify_schedule('schedule_updated')
        redirect_to schedule_destination, notice: t('admin.supplier_details.saved')
      else
        load_branches
        render :edit, status: :unprocessable_content
      end
    end

    def restore
      @schedule = @supplier.supplier_schedules.with_deleted.where.not(deleted_at: nil).find(params[:id])
      restored = @supplier.with_lock { @schedule.restore_safely }
      restored ? schedule_restore_success : schedule_restore_error
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.cause.is_a?(PG::ExclusionViolation)

      redirect_to admin_supplier_schedules_path(@supplier), alert: t('errors.messages.taken')
    end

    def destroy
      @schedule.update!(deleted_at: Time.current)
      notify_schedule('schedule_deleted')
      redirect_to schedule_destination, notice: t('admin.supplier_details.deleted')
    end

    private

    def schedule_destination
      return admin_supplier_path(@supplier, tab: 'schedules') if params[:return_to] == 'dossier'

      admin_supplier_schedules_path(@supplier)
    end

    def schedule_restore_success
      notify_schedule('schedule_restored')
      redirect_to schedule_destination, notice: t('admin.supplier_details.saved')
    end

    def schedule_restore_error
      redirect_to admin_supplier_schedules_path(@supplier), alert: @schedule.errors.full_messages.to_sentence
    end

    def load_exceptions
      @archived_exceptions = params[:archived] == '1'
      scope = exception_scope
      @exceptions_total = scope.count
      @exceptions_pages = [(@exceptions_total.to_f / 20).ceil, 1].max
      @exceptions_page = params[:page].to_i.clamp(1, @exceptions_pages)
      @exceptions = scope.includes(:branch, :supplier_schedule).order(starts_on: :desc, id: :desc)
                         .limit(20).offset((@exceptions_page - 1) * 20)
    end

    def exception_scope
      scope = @supplier.supplier_schedule_exceptions
      @archived_exceptions ? scope.with_deleted.where.not(deleted_at: nil) : scope
    end

    def save_schedule
      @supplier.with_lock { @schedule.save }
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.cause.is_a?(PG::ExclusionViolation)

      @schedule.errors.add(:starts_at, :taken)
      false
    end

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
