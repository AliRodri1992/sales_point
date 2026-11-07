# frozen_string_literal: true

module Admin
  class EmailTemplatesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :load_template, except: %i[index new create]
    before_action :load_version, only: %i[update_draft publish restore]

    include EmailTemplatePreviews

    def index
      authorize EmailTemplate
      scope = EmailTemplatesQuery.new(policy_scope(EmailTemplate), params).call
      @total = scope.count
      @total_pages = [(@total + 19) / 20, 1].max
      @page = [[params[:page].to_i, 1].max, @total_pages].min
      @templates = scope.includes(:organization, :published_version)
                        .order(updated_at: :desc).limit(20).offset((@page - 1) * 20)
      @counts = policy_scope(EmailTemplate).group(:status).count
    end

    def show
      authorize @template
      @versions = policy(@template).versions? ? @template.versions.order(version_number: :desc) : []
      @audits = @template.audits.includes(:actor).order(created_at: :desc).limit(30)
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
      @template = EmailTemplate.new(template_attributes)
      authorize @template
      raise Pundit::NotAuthorizedError unless current_organization || current_user.role?('super_admin')

      @template.prepare_for_creation!(actor: current_user, organization: current_organization,
                                      global: current_user.role?('super_admin') && params[:global] == '1')
      save_new_template
    end

    def save_new_template
      if current_organization.nil? && params[:global] != '1'
        @template.errors.add(:base, t('admin.email_templates.organization_required'))
        return render :new, status: :unprocessable_content
      end

      if @template.save
        draft = @template.new_draft!(actor: current_user)
        @template.audit!(action: 'created', actor: current_user, version: draft)
        redirect_to admin_email_template_path(@template), notice: t('admin.email_templates.saved')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update_draft
      authorize @template, :update?
      raise Pundit::NotAuthorizedError unless @version.status == 'draft'

      if @version.update(draft_attributes)
        @template.audit!(action: 'draft_updated', actor: current_user, version: @version)
        redirect_to edit_admin_email_template_path(@template), notice: t('admin.email_templates.saved')
      else
        @draft = @version
        render :edit, status: :unprocessable_content
      end
    end

    def publish
      authorize @template, :publish?
      @version.publish!(actor: current_user)
      @template.audit!(action: 'published', actor: current_user, version: @version)
      redirect_to admin_email_template_path(@template), notice: t('admin.email_templates.published')
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      message = @version.status == 'draft' ? e.message : t('admin.email_templates.publish_not_draft')
      redirect_to admin_email_template_path(@template), alert: message
    end

    def restore
      authorize @template, :versions?
      authorize @template, :update?
      raise ArgumentError, t('admin.email_templates.restore_not_published') unless @version.status == 'published'

      draft = @template.new_draft!(actor: current_user)
      draft.update!(subject: @version.subject, preheader: @version.preheader,
                    html_body: @version.html_body, text_body: @version.text_body,
                    allowed_variables: @version.allowed_variables)
      @template.audit!(action: 'restored', actor: current_user, version: draft)
      redirect_to edit_admin_email_template_path(@template), notice: t('admin.email_templates.restored')
    rescue ArgumentError => e
      redirect_to admin_email_template_path(@template), alert: e.message
    end

    def archive
      authorize @template, :archive?
      @template.update!(status: 'archived', enabled: false)
      @template.audit!(action: 'archived', actor: current_user)
      redirect_to admin_email_templates_path, notice: t('admin.email_templates.archived')
    end

    def compare
      authorize @template, :versions?
      @left = @template.versions.find(params[:left])
      @right = @template.versions.find(params[:right])
      render :compare
    end

    def send_test
      authorize @template, :send_test?
      EmailTemplates::TestDelivery.call(
        template: @template, actor: current_user, recipient: params[:email]
      )
      redirect_to admin_email_template_path(@template), notice: t('admin.email_templates.test_queued')
    rescue ArgumentError => e
      message = {
        'Invalid recipient' => t('admin.email_templates.invalid_recipient'),
        'Template not published' => t('admin.email_templates.test_not_published'),
        'Test email limit reached' => t('admin.email_templates.test_limit_reached')
      }.fetch(e.message, e.message)
      redirect_to admin_email_template_path(@template), alert: message
    end

    private

    def load_template
      @template = policy_scope(EmailTemplate).find(params[:id])
    end

    def load_version
      @version = @template.versions.find(params[:version_id])
    end

    def template_attributes
      params.expect(email_template: %i[key name category locale subject html_body text_body])
    end

    def draft_attributes
      params.expect(email_template_version: %i[subject preheader html_body text_body allowed_variables_csv])
    end
  end
end
