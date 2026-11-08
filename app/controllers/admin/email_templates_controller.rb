# frozen_string_literal: true

module Admin
  class EmailTemplatesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :load_template, except: %i[index new create]
    before_action :load_version, only: %i[update_draft publish restore]

    include EmailTemplatePreviews
    include EmailTemplateListing
    include EmailTemplateLifecycle
    include EmailTemplateActivity

    def index
      authorize EmailTemplate
      load_template_catalog
    end

    def show
      authorize @template
      @versions = policy(@template).versions? ? @template.versions.order(version_number: :desc) : []
      @can_view_audits = current_user.permission?('email_template_audits.view')
      @audits = @can_view_audits ? @template.audits.includes(:actor).order(created_at: :desc).limit(30) : []
      load_show_preview if policy(@template).preview? && @template.published_version
    end

    def new
      @template = EmailTemplate.new(locale: I18n.locale.to_s, category: 'transactional')
      authorize @template
      raise Pundit::NotAuthorizedError unless current_organization || current_user.role?('super_admin')
    end

    def edit
      authorize @template, :update?
      @draft = @template.versions.where(status: 'draft').order(version_number: :desc).first ||
               @template.new_draft!(actor: current_user)
    end

    def create
      @template = EmailTemplate.new(template_attributes.merge(locale: I18n.locale.to_s))
      authorize @template
      raise Pundit::NotAuthorizedError unless current_organization || current_user.role?('super_admin')

      @template.prepare_for_creation!(actor: current_user, organization: current_organization,
                                      global: current_user.role?('super_admin') && params[:global] == '1')
      save_new_template
    end

    def personalize
      authorize @template, :personalize?
      raise Pundit::NotAuthorizedError unless current_organization

      target, created = EmailTemplates::Personalizer.call(
        source: @template, organization: current_organization, actor: current_user
      )
      @template = target
      notify_email_template('personalized') if created
      destination = policy(target).update? ? edit_admin_email_template_path(target) : admin_email_template_path(target)
      message = created ? 'personalized_toast' : 'customization_exists'
      redirect_to destination, status: :see_other, flash: { swal_message: t("admin.email_templates.#{message}") }
    end

    def update_draft
      authorize @template, :update?
      raise Pundit::NotAuthorizedError unless @version.status == 'draft'

      if @version.update(draft_attributes)
        @template.audit!(action: 'draft_updated', actor: current_user, version: @version)
        notify_email_template('draft_updated')
        redirect_to edit_admin_email_template_path(@template),
                    flash: { swal_message: t('admin.email_templates.draft_updated_toast') }
      else
        @draft = @version
        render :edit, status: :unprocessable_content
      end
    end

    def publish
      authorize @template, :publish?
      @version.publish!(actor: current_user)
      @template.audit!(action: 'published', actor: current_user, version: @version)
      notify_email_template('published')
      redirect_to admin_email_template_path(@template),
                  flash: { swal_message: t('admin.email_templates.published') }
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      message = @version.status == 'draft' ? e.message : t('admin.email_templates.publish_not_draft')
      redirect_to admin_email_template_path(@template),
                  flash: { swal_message: message, swal_icon: 'error' }
    end

    def restore
      authorize @template, :versions?
      authorize @template, :update?
      raise ArgumentError, t('admin.email_templates.restore_not_published') unless @version.status == 'published'

      draft = @template.new_draft!(actor: current_user)
      draft.update!(@version.attributes.slice(*%w[subject preheader html_body text_body allowed_variables]))
      @template.audit!(action: 'restored', actor: current_user, version: draft)
      notify_email_template('restored')
      redirect_to edit_admin_email_template_path(@template),
                  flash: { swal_message: t('admin.email_templates.restored') }
    rescue ArgumentError => e
      redirect_to admin_email_template_path(@template),
                  flash: { swal_message: e.message, swal_icon: 'error' }
    end

    def compare
      authorize @template, :versions?
      @left = @template.versions.find(params[:left])
      @right = @template.versions.find(params[:right])
      @comparison_previews = [@left, @right].to_h { |version| [version.id, comparison_preview(version)] }
      render :compare
    end

    def send_test
      authorize @template, :send_test?
      EmailTemplates::TestDelivery.call(
        template: @template, actor: current_user, recipient: params[:email]
      )
      notify_email_template('test_queued')
      redirect_to admin_email_template_path(@template),
                  flash: { swal_message: t('admin.email_templates.test_queued') }
    rescue ArgumentError => e
      message = {
        'Invalid recipient' => t('admin.email_templates.invalid_recipient'),
        'Template not published' => t('admin.email_templates.test_not_published'),
        'Test email limit reached' => t('admin.email_templates.test_limit_reached')
      }.fetch(e.message, e.message)
      redirect_to admin_email_template_path(@template),
                  flash: { swal_message: message, swal_icon: 'error' }
    end

    private

    def load_template
      @template = policy_scope(EmailTemplate).find(params[:id])
    end

    def load_version
      @version = @template.versions.find(params[:version_id])
    end

    def template_attributes
      params.expect(email_template: %i[key name category])
    end

    def draft_attributes
      params.expect(email_template_version: %i[subject preheader html_body text_body allowed_variables_csv])
    end
  end
end
