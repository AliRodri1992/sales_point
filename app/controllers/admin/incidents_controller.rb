module Admin
  class IncidentsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action { head :forbidden unless current_organization }
    before_action :load_incident, only: %i[show update attachment]

    def index
      @page = [params[:page].to_i, 1].max
      @incidents = tenant.where(reporter: current_user).order(created_at: :desc, id: :desc).offset((@page - 1) * 25).limit(26).to_a
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
      mod, screen = @incident.origin_screen.to_s.split('#', 2)
      return unless Incident::SCREENS.key?(mod)

      @incident.affected_module = mod
      @incident.affected_screen = screen if Incident::SCREENS.fetch(mod).include?(screen)
    end

    def create
      @incident = build_incident
      authorize @incident
      @incident.assign_attributes(params.require(:incident).permit(:description, :expected_result, :category,
        :frequency, :blocks_operation, :affected_module, :affected_screen, :operation_reference, :occurred_at))
      uploads = Array(params.dig(:incident, :attachments)).grep(ActionDispatch::Http::UploadedFile)
      @incident.attachments.attach(uploads) if uploads.any?
      if @incident.save
        enqueue_sync
        flash[:notice] = t('incidents.created')
        respond_to do |format|
          format.html { redirect_to admin_incident_path(@incident), notice: t('incidents.created') }
          format.json { render json: { url: admin_incident_path(@incident) }, status: :created }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_content }
          format.json { render json: { errors: @incident.errors.full_messages }, status: :unprocessable_content }
        end
      end
    end

    def update
      authorize @incident, :manage?
      changes = params.require(:incident).permit(:status, :priority, :resolution)
      return head :unprocessable_content unless %w[reported reviewing resolved].include?(changes[:status])
      return head :unprocessable_content if changes[:status] == 'resolved' && changes[:resolution].blank?

      @incident.with_lock do
        resolved = changes[:status] == 'resolved'
        @incident.update!(changes.merge(resolved_by: resolved ? current_user : nil, resolved_at: resolved ? Time.current : nil,
                                        assignee: current_user))
        @incident.incident_events.create!(actor: current_user, kind: @incident.status, body: @incident.resolution)
      end
      redirect_to admin_incident_path(@incident)
    end

    private

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

    def build_incident
      context = Rails.application.message_verifier(:incident_origin).verified(params[:origin].to_s)
      context = context&.with_indifferent_access || {}
      context = {} unless context[:user_id] == current_user.id && context[:organization_id] == current_organization.id
      tenant.new(reporter: current_user, branch: current_branch, reporter_role: current_user.display_role_name,
                 origin_screen: context[:screen], origin_path: context[:path], request_reference: context[:request_id],
                 app_version: ENV['RELEASE_SHA'].presence)
    end
  end
end
