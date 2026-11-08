# frozen_string_literal: true

# Version comparisons and inline publication failure handling.
module EmailTemplateVersionActions
  def compare
    authorize @template, :versions?
    load_comparison_versions
    return redirect_same_version if @left.id == @right.id

    @comparison_previews = [@left, @right].to_h do |version|
      [version.id, comparison_preview(version)]
    end
    render :compare
  end

  def update_draft
    authorize @template, :update?
    raise Pundit::NotAuthorizedError unless @version.status == 'draft'

    if save_draft_changes
      notify_email_template('draft_updated')
      redirect_to edit_admin_email_template_path(@template),
                  flash: { swal_message: t('admin.email_templates.draft_updated_toast') }
    else
      @draft = @version
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::StaleObjectError
    @draft = @version
    @draft.errors.add(:subject, :stale_draft)
    render :edit, status: :conflict
  end

  private

  def save_draft_changes
    EmailTemplate.transaction do
      next false unless @version.update(draft_attributes)

      @template.update!(updated_by: current_user)
      @template.touch
      @template.audit!(action: 'draft_updated', actor: current_user, version: @version)
      true
    end
  end

  def restore_published_version!
    EmailTemplate.transaction do
      @template.with_lock do
        if @template.versions.exists?(status: 'draft')
          raise ArgumentError, t('admin.email_templates.restore_existing_draft')
        end

        draft = @template.new_draft!(actor: current_user)
        draft.update!(@version.attributes.slice(*%w[subject preheader html_body text_body allowed_variables]))
        @template.audit!(action: 'restored', actor: current_user, version: draft)
      end
    end
  end

  def load_comparison_versions
    @versions = @template.versions.order(version_number: :desc).to_a
    @left = @template.versions.find(params[:left])
    @right = @template.versions.find(params[:right])
  end

  def handle_publish_validation_error(error)
    if error.record.is_a?(EmailTemplateVersion) && policy(@template).update?
      @draft = @version
      @draft.status = 'draft'
      render :edit, status: :unprocessable_content
    else
      redirect_publish_error(error.message)
    end
  end

  def redirect_publish_error(message)
    redirect_to admin_email_template_path(@template),
                flash: { swal_message: message, swal_icon: 'error' }
  end

  def redirect_same_version
    redirect_to admin_email_template_path(@template),
                flash: { swal_message: t('admin.email_templates.compare_distinct'), swal_icon: 'error' }
  end
end
