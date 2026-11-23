# frozen_string_literal: true

module Admin
  class CommercialCatalogController < ApplicationController
    include CatalogNavigation
    include Admin::CommercialLookups

    TRANSITIONS = %w[activate pause resume archive duplicate].freeze
    FILTERS = %i[search status currency product_id category_id customer_segment validity benefit_kind usage
                 sort direction].freeze
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_organization
    before_action :set_record, only: %i[show edit update destroy transition preview]
    before_action :authorize_commercial_action

    def index
      scope = CommercialCatalogQuery.new(commercial_scope, params.permit(*FILTERS)).call
      paginate_records(scope)
      @selected_product = current_organization.products.find_by(id: params.permit(:product_id)[:product_id])
      prepare_index(scope)
    end

    def show
      prepare_show
      render :show
    end

    def new
      @record = commercial_scope.new(currency: base_currency)
      render_form
    end

    def edit
      return render_locked unless editable_record?

      render_form
    end

    def create
      @record = commercial_scope.new(currency: base_currency)
      save_or_render
    end

    def update = save_or_render

    def destroy = perform_transition('archive')

    def transition = perform_transition(params[:commercial_action])

    private

    def paginate_records(scope)
      @total_count = scope.count
      @per_page = table_page_size_for(controller_name)
      @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
      @current_page = params[:page].to_s.to_i.clamp(1, @total_pages)
      @records = page_records(scope.limit(@per_page).offset((@current_page - 1) * @per_page))
    end

    def require_organization
      raise ActiveRecord::RecordNotFound unless current_organization
    end

    def authorize_commercial_action
      if %w[products_lookup categories_lookup].include?(action_name)
        permissions = policy(resource_class)
        raise Pundit::NotAuthorizedError unless permissions.index? || permissions.show? ||
                                                permissions.create? || permissions.update?
      else
        authorize(@record || resource_class, "#{permission_action}?")
      end
    end

    def permission_action
      return 'show' if action_name == 'preview'
      return action_name unless action_name == 'transition'
      return params[:commercial_action] if TRANSITIONS.include?(params[:commercial_action])

      raise ActionController::BadRequest, 'Invalid commercial action'
    end

    def perform_transition(action)
      result = Commercial::Lifecycle.new(record: @record, actor: current_user).call(action)
      destination = action_name == 'destroy' ? catalog_back_path(resource_class) : success_path(result)
      redirect_to destination, notice: t('admin.catalog_design.saved'), status: :see_other
    rescue ActiveRecord::RecordInvalid
      render_record_error
    end

    def render_record_error
      return head :unprocessable_content unless policy(@record).show?

      prepare_show
      render :show, status: :unprocessable_content
    end

    def render_locked
      @record.errors.add(:status, :invalid)
      render_record_error
    end

    def editable_record? = %w[draft active scheduled paused].include?(@record.effective_status)

    def commercial_scope = resource_class.where(organization: current_organization)

    def set_record
      @record = detail_scope.find(params[:id])
    end

    def base_currency
      current_organization.organization_settings.active_records.first&.base_currency&.code || 'MXN'
    end

    def prepare_show
      return unless policy(@record).history?

      @history = FinancialAuditEvent.where(organization: current_organization, subject_type: resource_class.name,
                                           subject_id: @record.id).preload(:actor).order(created_at: :desc, id: :desc)
                                    .limit(50)
    end

    def save_or_render
      saved = resource_class.transaction do
        @record.lock! if @record.persisted?
        @record.new_record? || editable_record? ? persist_with_audit : :locked
      end
      return render_locked if saved == :locked
      return render_form(:unprocessable_content) unless saved

      redirect_to success_path(@record), notice: t('admin.catalog_design.saved'), status: :see_other
    rescue ActiveRecord::NestedAttributes::TooManyRecords
      @record.errors.add(:base, :invalid)
      render_form(:unprocessable_content)
    end

    def persist_with_audit
      action = @record.new_record? ? 'create' : 'update'
      return false unless persist_record

      fields = @record.saved_changes.keys - %w[id created_at updated_at organization_id]
      FinancialAuditEvent.record!(organization: current_organization, actor: current_user, details: { fields: },
                                  event: "#{resource_class.model_name.singular}.#{action}", subject: @record)
      true
    end

    def success_path(record)
      policy(record).show? ? polymorphic_path([:admin, record]) : catalog_back_path(resource_class)
    end

    def render_form(status = :ok)
      render :form, status:
    end
  end
end
