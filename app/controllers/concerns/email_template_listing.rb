# frozen_string_literal: true

# Catalog pagination and filtering are shared by the email template listing.
module EmailTemplateListing
  private

  def load_template_catalog
    scope = EmailTemplatesQuery.new(policy_scope(EmailTemplate), params).call
    prepare_template_pagination(scope)
    @templates = paginated_templates(scope)
    @counts = policy_scope(EmailTemplate).group(:status).count
  end

  def prepare_template_pagination(scope)
    @total = scope.count
    @total_pages = [(@total + 19) / 20, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
  end

  def paginated_templates(scope)
    scope.includes(:organization, :published_version)
         .order(updated_at: :desc).limit(20).offset((@page - 1) * 20)
  end
end
