# frozen_string_literal: true

module Admin
  class EmailTemplatesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :load_template, except: %i[index new create]
    before_action :load_version, only: %i[update_draft publish restore]

    def index
      authorize EmailTemplate
      scope = EmailTemplatesQuery.new(policy_scope(EmailTemplate), params).call
      @total = scope.count
      @page = [params[:page].to_i, 1].max
      @templates = scope.includes(:organization, :published_version)
                        .order(updated_at: :desc).limit(20).offset((@page - 1) * 20)
      @counts = policy_scope(EmailTemplate).group(:status).count
    end

    def show
      authorize @template
      @versions = @template.versions.order(version_number: :desc)
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
      redirect_to admin_email_template_path(@template), alert: e.message
    end

    def restore
      authorize @template, :versions?
      raise ArgumentError, 'Only published versions can be restored' unless @version.status == 'published'

      draft = @template.new_draft!(actor: current_user)
      draft.update!(subject: @version.subject, preheader: @version.preheader,
                    html_body: @version.html_body, text_body: @version.text_body,
                    allowed_variables: @version.allowed_variables)
      @template.audit!(action: 'restored', actor: current_user, version: draft)
      redirect_to edit_admin_email_template_path(@template), notice: t('admin.email_templates.restored')
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

    def preview
      authorize @template, :preview?
      @version = @template.versions.find_by(id: params[:version_id]) || @template.published_version
      raise ActiveRecord::RecordNotFound unless @version

      @subject, @html, @plain = EmailTemplates::Renderer.new(
        source: @version, values: EmailTemplates::SampleData.call(@template)
      ).render
      render :preview
    end

    def send_test
      authorize @template, :send_test?
      EmailTemplates::TestDelivery.call(
        template: @template, actor: current_user, recipient: params[:email]
      )
      redirect_to admin_email_template_path(@template), notice: t('admin.email_templates.test_queued')
    rescue ArgumentError => e
      redirect_to admin_email_template_path(@template), alert: e.message
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
      params.expect(email_template_version: %i[subject preheader html_body text_body])
    end
  end
end
