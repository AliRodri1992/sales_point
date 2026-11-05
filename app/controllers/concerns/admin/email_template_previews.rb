# frozen_string_literal: true

module Admin
  module EmailTemplatePreviews
    extend ActiveSupport::Concern

    included do
      before_action :load_preview_version, only: :preview_draft
    end

    def preview
      authorize @template, :preview?
      @version = @template.versions.find_by(id: params[:version_id]) || @template.published_version
      raise ActiveRecord::RecordNotFound unless @version

      @subject, @html, @plain = EmailTemplates::Renderer.new(
        source: @version, values: EmailTemplates::SampleData.call(@template)
      ).render
      render :preview
    end

    # Render the unsaved editor content without changing the stored draft.
    def preview_draft
      authorize @template, :update?
      raise Pundit::NotAuthorizedError unless @version.status == 'draft'

      source = @version.dup
      source.assign_attributes(draft_attributes)
      subject, html, plain = EmailTemplates::Renderer.new(
        source:, values: EmailTemplates::SampleData.call(@template)
      ).render
      render json: { subject:, html:, plain: }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def load_preview_version
      @version = @template.versions.find(params[:version_id])
    end
  end
end
