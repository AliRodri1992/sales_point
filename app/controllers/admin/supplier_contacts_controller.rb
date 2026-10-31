# frozen_string_literal: true

module Admin
  class SupplierContactsController < ApplicationController
    include SupplierAuditTrail

    ACTION_POLICY = {
      'index' => :view_contacts?, 'new' => :create_contacts?, 'create' => :create_contacts?,
      'edit' => :update_contacts?, 'update' => :update_contacts?,
      'destroy' => :destroy_contacts?, 'restore' => :restore_contacts?
    }.freeze

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_supplier
    before_action :set_contact, only: %i[edit update destroy]

    def index
      @contact = @supplier.contacts.new
      @contacts = @supplier.contacts.not_deleted.order(primary: :desc, name: :asc)
      load_contact_listing
    end

    def load_contact_listing
      scope = params[:status] == 'deleted' ?
        @supplier.contacts.with_deleted.where.not(deleted_at: nil) : @supplier.contacts.not_deleted
      query = params[:q].to_s.strip.first(100)
      if query.present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        scope = scope.where('name ILIKE :q OR position ILIKE :q OR email ILIKE :q', q: term)
      end
      @contacts_total = scope.count
      @contacts_pages = [(@contacts_total.to_f / 12).ceil, 1].max
      @contacts_page = params[:page].to_i.clamp(1, @contacts_pages)
      @listed_contacts = scope.order(primary: :desc, name: :asc, id: :asc)
                              .limit(12).offset((@contacts_page - 1) * 12)
    end

    def new
      @contact = @supplier.contacts.new
    end

    def edit; end

    def create
      @contact = @supplier.contacts.new(contact_params.except(:active))
      @contact.active = true
      if @contact.save
        notify_contact('contact_created')
        redirect_success('contact_created')
      else
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @contact.errors.add(:primary, :taken)
      render :new, status: :unprocessable_content
    end

    def update
      if @contact.update(contact_params)
        notify_contact('contact_updated')
        redirect_success('contact_updated')
      else
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @contact.errors.add(:primary, :taken)
      render :edit, status: :unprocessable_content
    end

    def restore
      record = @supplier.contacts.with_deleted.where.not(deleted_at: nil).find(params[:id])
      if record.restore_safely
        @contact = record
        notify_contact('contact_restored')
        redirect_success('contact_restored')
      else
        redirect_to admin_supplier_contacts_path(@supplier), alert: record.errors.full_messages.to_sentence
      end
    end

    def destroy
      @contact.update!(deleted_at: Time.current)
      notify_contact('contact_deleted')
      redirect_success('contact_deleted')
    end

    private

    def set_supplier
      return head :forbidden unless current_organization

      @supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:supplier_id])
      authorize @supplier, ACTION_POLICY.fetch(action_name)
    end

    def set_contact
      @contact = @supplier.contacts.not_deleted.find(params[:id])
    end

    def notify_contact(action)
      Suppliers::NotifyService.call(action: action, supplier: @supplier, user: current_user, subject: @contact)
    end

    def redirect_success(action)
      redirect_to admin_supplier_contacts_path(@supplier),
                  flash: { swal_message: t("admin.supplier_details.#{action}", name: @supplier.name) }
    end

    def contact_params
      params.expect(contact: %i[name position email phone mobile_phone notes primary active])
    end
  end
end
