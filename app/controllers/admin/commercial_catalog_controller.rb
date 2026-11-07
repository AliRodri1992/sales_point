# frozen_string_literal: true

module Admin
  class CommercialCatalogController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :authorize_commercial_action
    before_action :set_record, only: %i[show edit update destroy]

    def index
      paginate_records(filtered_records)
      render 'admin/commercial_catalog/index'
    end

    def show
      render 'admin/commercial_catalog/show'
    end

    def new
      @record = commercial_scope.new(currency: base_currency)
      render 'admin/commercial_catalog/form'
    end

    def edit
      render 'admin/commercial_catalog/form'
    end

    def create
      @record = commercial_scope.new
      save_or_render
    end

    def update
      save_or_render
    end

    def destroy
      @record.update!(status: 'archived')
      redirect_to polymorphic_path([:admin, resource_class]), notice: t('admin.catalog_design.archived_notice'),
                                                              status: :see_other
    end

    private

    def authorize_commercial_action
      raise ActiveRecord::RecordNotFound unless current_organization

      action = { 'new' => 'create', 'edit' => 'update' }.fetch(action_name, action_name)
      authorize resource_class, "#{action}?"
    end

    def commercial_scope
      resource_class.where(organization: current_organization)
    end

    def set_record
      @record = commercial_scope.find(params[:id])
    end

    def filtered_records
      scope = commercial_scope.order(:name)
      scope = scope.where(status: params[:status]) if resource_class.statuses.key?(params[:status])
      return scope if params[:search].blank?

      query = "%#{resource_class.sanitize_sql_like(params[:search].strip)}%"
      scope.where('name ILIKE :q OR code ILIKE :q', q: query)
    end

    def paginate_records(scope)
      @total_count = scope.count
      @per_page = table_page_size_for(controller_name)
      @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
      @current_page = params[:page].to_s.to_i.clamp(1, @total_pages)
      @records = scope.limit(@per_page).offset((@current_page - 1) * @per_page)
    end

    def base_currency
      current_organization.organization_settings.active_records.first&.base_currency&.code || 'MXN'
    end

    def persist_record
      @record.with_lock do
        @record.assign_attributes(record_params)
        @record.save!
      end
    rescue ActiveRecord::RecordInvalid
      false
    end

    def save_or_render
      if persist_record
        redirect_to polymorphic_path([:admin, @record]), notice: t('admin.catalog_design.saved'), status: :see_other
      else
        render 'admin/commercial_catalog/form', status: :unprocessable_content
      end
    end
  end
end
