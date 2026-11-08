# frozen_string_literal: true

module Admin
  class EmailTemplatesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :load_template, except: %i[index new create]
    before_action :load_version, only: %i[update_draft publish restore]
    after_action :clear_email_template_access, only: :index

    include EmailTemplatePreviews
    include EmailTemplateListing
    include EmailTemplateLifecycle
    include EmailTemplatePersonalization
    include EmailTemplateActivity
    include EmailTemplateTestSending
    include EmailTemplateVersionActions

    def index
      authorize EmailTemplate
      load_template_catalog
    end

    def show
      authorize @template
      @test_recipient = EmailTemplates::TestRecipient.new(
        email: (current_user.email unless current_user.role?('super_admin')), actor: current_user
      )
      load_show_details
    end

    def new
      @template = EmailTemplate.new(locale: I18n.locale.to_s, category: 'transactional')
      authorize @template
      raise Pundit::NotAuthorizedError unless current_organization || current_user.role?('super_admin')

      load_new_categories
    end

    def edit
      authorize @template, :update?
      @draft = @template.versions.where(status: 'draft').order(version_number: :desc).first
      return if @draft

      redirect_to admin_email_template_path(@template),
                  status: :see_other,
                  flash: { swal_message: t('admin.email_templates.create_draft_first') }
    end

    def start_draft
      authorize @template, :update?
      @template.new_draft!(actor: current_user)
      redirect_to edit_admin_email_template_path(@template), status: :see_other
    end

    def create
      @template = EmailTemplate.new(template_attributes)
      @template.locale ||= I18n.locale.to_s
      authorize @template
      raise Pundit::NotAuthorizedError unless current_organization || current_user.role?('super_admin')

      @template.prepare_for_creation!(actor: current_user, organization: current_organization,
                                      global: current_user.role?('super_admin') && params[:global] == '1')
      load_new_categories
      save_new_template
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
      EmailTemplate.transaction do
        @version.publish!(actor: current_user)
        @template.audit!(action: 'published', actor: current_user, version: @version)
      end
      notify_email_template('published')
      redirect_to admin_email_template_path(@template),
                  flash: { swal_message: t('admin.email_templates.published') }
    rescue ActiveRecord::RecordInvalid => e
      handle_publish_validation_error(e)
    rescue ArgumentError => e
      redirect_publish_error(e.message)
    end

    def restore
      authorize @template, :versions?
      authorize @template, :update?
      raise ArgumentError, t('admin.email_templates.restore_not_published') unless @version.status == 'published'

      draft = EmailTemplate.transaction do
        @template.with_lock do
          raise ArgumentError, t('admin.email_templates.restore_existing_draft') if @template.versions.exists?(status: 'draft')

          restored = @template.new_draft!(actor: current_user)
          restored.update!(@version.attributes.slice(*%w[subject preheader html_body text_body allowed_variables]))
          @template.audit!(action: 'restored', actor: current_user, version: restored)
          restored
        end
      end
      notify_email_template('restored')
      redirect_to edit_admin_email_template_path(@template),
                  flash: { swal_message: t('admin.email_templates.restored') }
    rescue ArgumentError => e
      redirect_to admin_email_template_path(@template),
                  flash: { swal_message: e.message, swal_icon: 'error' }
    end

    private

    def load_show_details
      @versions = policy(@template).versions? ? @template.versions.order(version_number: :desc) : []
      @can_view_audits = policy(EmailTemplateAudit).index?
      @audits = if @can_view_audits
                  @template.audits.includes(:actor, :email_template_version)
                           .order(created_at: :desc).limit(30)
                else
                  []
                end
      load_show_preview if policy(@template).preview? && @template.published_version
    end

    def load_template
      @template = policy_scope(EmailTemplate).find(params[:id])
    end

    def load_version
      @version = @template.versions.find(params[:version_id])
    end

    def load_new_categories
      defaults = %w[transactional security notifications marketing system]
      existing = policy_scope(EmailTemplate).distinct.pluck(:category)
      @categories = (defaults + existing + [@template.category]).compact_blank.uniq.sort
    end

    def template_attributes
      params.expect(email_template: %i[key name category locale])
    end

    def draft_attributes
      params.expect(email_template_version: %i[subject preheader html_body text_body allowed_variables_csv])
    end
  end
end
