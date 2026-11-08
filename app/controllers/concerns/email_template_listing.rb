# frozen_string_literal: true

# Email template catalog pagination and filtering.
module EmailTemplateListing
  private

  def load_template_catalog
    visible = policy_scope(EmailTemplate)
    preload_email_template_access
    @categories = visible.distinct.order(:category).pluck(:category).compact_blank
    scope = EmailTemplatesQuery.new(visible, params).call
    prepare_template_pagination(scope)
    @templates = paginated_templates(scope)
    @counts = EmailTemplatesQuery.new(visible, params.except(:status), include_archived: true)
                                  .call.group(:status).count
  end

  def preload_email_template_access
    permissions = current_user.user_roles.active.joins(system_role: :permissions)
                              .where(permissions: { status: 'active' }).pluck('permissions.code').to_set
    current_user.email_template_policy_snapshot = EmailTemplatePolicy::ListingSnapshot.new(
      active_admin: current_user.active? && current_user.admin?,
      super_admin: current_user.role?('super_admin'),
      permissions:, organization_ids: current_user.organization_memberships.accessible
                                                   .pluck(:organization_id).to_set
    )
  end

  def clear_email_template_access
    current_user.email_template_policy_snapshot = nil
  end

  def prepare_template_pagination(scope)
    @total = scope.count
    @per_page = table_page_size_for('email_templates')
    @total_pages = [(@total.to_f / @per_page).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
  end

  def paginated_templates(scope)
    scope.includes(:organization, :published_version)
         .order(updated_at: :desc, id: :desc).limit(@per_page).offset((@page - 1) * @per_page)
  end
end
