module Admin
  class IncidentsController < ApplicationController
    REPORT_FIELDS = %i[description expected_result category frequency blocks_operation affected_module affected_screen
                       operation_reference occurred_at].freeze

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action { head :forbidden unless current_organization }
    before_action :load_incident, only: %i[show update attachment]

    def index
      @page = [params[:page].to_i, 1].max
      @can_manage = policy(tenant.new).manage?
      @team = @can_manage && params[:view] == 'team'
      scope = @team ? tenant : tenant.where(reporter: current_user)
      @incidents = scope.order(created_at: :desc, id: :desc)
                        .offset((@page - 1) * 25).limit(26).to_a
      @more = @incidents.size > 25
      @incidents.pop if @more
    end

    def show
      authorize @incident
    end

    def attachment
      authorize @incident, :show?
      file = @incident.attachments.find(params[:attachment_id])
      send_data file.download, filename: file.filename.to_s, disposition: :attachment, type: file.content_type
    end

    def new
      @incident = build_incident
      authorize @incident
      @incident.submission_key = SecureRandom.uuid
      mod, screen = @incident.origin_screen.to_s.split('#', 2)
      return unless Incident::SCREENS.key?(mod)

      @incident.affected_module = mod
      @incident.affected_screen = screen if Incident::SCREENS.fetch(mod).include?(screen)
    end

    def create
      @incident = build_incident
      authorize @incident
      @incident.submission_key = submission_key
      existing = previous_submission
      return registration_response(existing) if existing

      persist_registration
    rescue ActiveRecord::RecordNotUnique
      raise unless @incident.submission_key

      registration_response(tenant.find_by!(reporter: current_user, submission_key: @incident.submission_key))
    end

    def update
      authorize @incident, :manage?
      changes = params.expect(incident: %i[status priority resolution])
      @incident.record_followup!(current_user, changes)
      redirect_to admin_incident_path(@incident)
    rescue ActiveRecord::RecordInvalid
      render :show, status: :unprocessable_content
    end

    private

    def persist_registration
      @incident.assign_attributes(params.expect(incident: REPORT_FIELDS))
      attach_uploads
      return invalid_registration unless @incident.save

      enqueue_sync
      registration_response(@incident)
    end

    def registration_response(record)
      flash.update(notice: t('incidents.created'))
      respond_to do |format|
        format.html { redirect_to admin_incident_path(record) }
        format.json { render json: { url: admin_incident_path(record) }, status: :created }
      end
    end

    def enqueue_sync
      IncidentGithubJob.perform_later(@incident.id) if Incidents::Github.configured?
    rescue RedisClient::Error, ActiveJob::EnqueueError => e
      Rails.logger.warn("Incident #{@incident.folio}: enqueue failed (#{e.class})")
    end

    def tenant
      Incident.where(organization: current_organization)
    end

    def load_incident
      @incident = tenant.find_by!(folio: params[:id])
    end

    def attach_uploads
      uploads = Array(params.dig(:incident, :attachments)).grep(ActionDispatch::Http::UploadedFile)
      @incident.attachments.attach(uploads) if uploads.any?
    end

    def submission_key
      key = params.dig(:incident, :submission_key).to_s
      key if key.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i)
    end

    def previous_submission
      tenant.find_by(reporter: current_user, submission_key: @incident.submission_key) if @incident.submission_key
    end

    def invalid_registration
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: { errors: @incident.errors.full_messages }, status: :unprocessable_content }
      end
    end

    def origin_context
      token = Rails.application.message_verifier(:incident_origin).verified(params[:origin].to_s)
      context = token&.with_indifferent_access || {}
      return {} unless context[:user_id] == current_user.id && context[:organization_id] == current_organization.id

      context
    end

    def build_incident
      context = origin_context
      tenant.new(reporter: current_user, branch: current_branch, reporter_role: current_user.display_role_name,
                 origin_screen: context[:screen], origin_path: context[:path], request_reference: context[:request_id],
                 app_version: ENV['RELEASE_SHA'].presence)
    end
  end
end
