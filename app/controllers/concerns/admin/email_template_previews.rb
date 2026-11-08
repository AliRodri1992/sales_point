# frozen_string_literal: true

module Admin
  module EmailTemplatePreviews
    extend ActiveSupport::Concern

    included do
      before_action :load_preview_version, only: :preview_draft
    end

    def preview
      authorize @template, :preview?
      authorize @template, :versions? if params[:version_id].present?
      @version = saved_preview_version
      raise ActiveRecord::RecordNotFound unless @version

      @subject, @html, @plain = EmailTemplates::Renderer.new(
        source: @version, values: EmailTemplates::SampleData.call(@template), preview: true
      ).render
      render :preview
    rescue ArgumentError
      redirect_invalid_saved_preview
    end

    # Render the unsaved editor content without changing the stored draft.
    def preview_draft
      authorize @template, :update?
      raise Pundit::NotAuthorizedError unless @version.status == 'draft'

      # Validate a persisted version in memory: dup would trigger the unique version number constraint.
      source = @version
      source.assign_attributes(draft_attributes)
      return render_invalid_preview(source) unless source.valid?

      validate_draft_preview_variables!(source)
      subject, html, plain = EmailTemplates::Renderer.new(
        source:, values: EmailTemplates::SampleData.call(@template), preview: true
      ).render
      render json: { subject:, html:, plain: }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def saved_preview_version
      return @template.published_version if params[:version_id].blank?

      @template.versions.find(params[:version_id])
    end

    def redirect_invalid_saved_preview
      message = t('admin.email_templates.detail_preview_error')
      redirect_to admin_email_template_path(@template), status: :see_other,
                  flash: { swal_message: message, swal_icon: 'error' }
    end

    def render_invalid_preview(source)
      key = if source.errors.added?(:allowed_variables, :undeclared_placeholders)
              'admin.email_templates.preview_undeclared_variables'
            else
              'admin.email_templates.preview_error'
            end
      render json: { error: t(key), errors: source.errors.to_hash }, status: :unprocessable_content
    end

    def load_show_preview
      @preview_subject, @preview_html, @preview_plain = EmailTemplates::Renderer.new(
        source: @template.published_version, values: EmailTemplates::SampleData.call(@template), preview: true
      ).render
    rescue ArgumentError
      @preview_error = true
    end

    def validate_draft_preview_variables!(source)
      used = [source.subject, source.html_body, source.text_body].flat_map do |body|
        body.to_s.scan(EmailTemplates::Renderer::VARIABLE_PATTERN).flatten
      end.uniq
      return if (used - Array(source.allowed_variables)).empty?

      raise ArgumentError, t('admin.email_templates.preview_undeclared_variables')
    end

    def comparison_preview(version)
      _subject, html, plain = EmailTemplates::Renderer.new(
        source: version, values: EmailTemplates::SampleData.call(@template), preview: true
      ).render
      { html:, plain: }
    rescue ArgumentError
      { html: nil, plain: nil }
    end

    def load_preview_version
      @version = @template.versions.find(params[:version_id])
    end
  end
end
