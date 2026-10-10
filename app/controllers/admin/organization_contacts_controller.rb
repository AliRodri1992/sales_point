# frozen_string_literal: true

module Admin
  class OrganizationContactsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_organization
    before_action :set_contact, only: %i[edit update destroy]

    def index
      @contacts = @organization.contacts.not_deleted.order(primary: :desc, name: :asc)
    end

    def new
      @contact = @organization.contacts.new
    end

    def edit; end

    def create
      @contact = @organization.contacts.new(contact_params)
      if @contact.save
        redirect_to admin_organization_contacts_path, notice: t('admin.supplier_details.saved')
      else
        render :new, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @contact.errors.add(:primary, :taken)
      render :new, status: :unprocessable_content
    end

    def update
      if @contact.update(contact_params)
        redirect_to admin_organization_contacts_path, notice: t('admin.supplier_details.saved')
      else
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::RecordNotUnique
      @contact.errors.add(:primary, :taken)
      render :edit, status: :unprocessable_content
    end

    def restore
      record = @organization.contacts.with_deleted.where.not(deleted_at: nil).find(params[:id])
      if record.restore_safely
        redirect_to admin_organization_contacts_path, notice: t('admin.supplier_details.restored')
      else
        redirect_to admin_organization_contacts_path, alert: record.errors.full_messages.to_sentence
      end
    end

    def destroy
      @contact.update!(deleted_at: Time.current)
      redirect_to admin_organization_contacts_path, notice: t('admin.supplier_details.deleted')
    end

    private

    def set_organization
      return head :forbidden unless current_user&.admin?

      @organization = current_organization
      return head :forbidden unless @organization
    end

    def set_contact
      @contact = @organization.contacts.not_deleted.find(params[:id])
    end

    def contact_params
      params.expect(contact: %i[name position email phone mobile_phone notes primary active])
    end
  end
end
