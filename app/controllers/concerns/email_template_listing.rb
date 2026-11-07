# frozen_string_literal: true

# Email template catalog pagination and filtering.
module EmailTemplateListing
  private

  def load_template_catalog
    visible = policy_scope(EmailTemplate)
    @categories = visible.distinct.order(:category).pluck(:category).compact_blank
    scope = EmailTemplatesQuery.new(visible, params).call
    prepare_template_pagination(scope)
    @templates = paginated_templates(scope)
    @counts = visible.group(:status).count
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
