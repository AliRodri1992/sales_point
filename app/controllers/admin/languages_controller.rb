# frozen_string_literal: true

module Admin
  class LanguagesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_language, only: %i[show edit update destroy generate retry_generation resume_generation cancel_generation]
    before_action :set_deleted_language, only: %i[restore really_destroy]
    before_action :check_permissions

    rescue_from Pundit::NotAuthorizedError, with: :forbidden

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze
    SORTABLE_COLUMNS = %w[name code status created_at updated_at].freeze

    def index
      load_languages
    end

    def show; end

    def new
      @language = Language.new
      authorize @language
    end

    def edit
      authorize @language
    end

    def create
      @language = Language.new(language_params)
      authorize @language

      if @language.save
        enqueue_generation
        load_languages
        notify_language(current_user, @language, 'created')
        broadcast_language_selector
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.languages.created') }
          format.html { redirect_to admin_languages_path(request.query_parameters), notice: t('admin.languages.created') }
        end
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @language

      if @language.update(language_params)
        enqueue_generation if @language.saved_change_to_code?
        load_languages
        notify_language(current_user, @language, 'updated')
        broadcast_language_selector
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.languages.updated') }
          format.html { redirect_to admin_languages_path(request.query_parameters), notice: t('admin.languages.updated') }
        end
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @language
      @language.destroy!
      load_languages
      notify_language(current_user, @language, 'destroyed')
      broadcast_language_selector
      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.languages.destroyed') }
        format.html { redirect_to admin_languages_path(request.query_parameters), notice: t('admin.languages.destroyed') }
      end
    end

    def generate
      authorize @language, :generate?
      generation = TranslationGeneration.enqueue_for!(@language, actor: current_user, force: true)
      redirect_to admin_language_path(@language), notice: "Translation generation ##{generation.id} queued."
    end

    def retry_generation
      generation = generation_for_request
      authorize @language, :retry_generation?
      generation = TranslationGenerationService.new(generation).retry
      redirect_to admin_language_path(@language), notice: "Translation generation ##{generation.id} retried."
    end

    def resume_generation
      generation = generation_for_request
      authorize @language, :resume_generation?
      generation.update!(status: :pending, cancelled_at: nil)
      TranslationGenerationJob.perform_later(generation.id)
      redirect_to admin_language_path(@language), notice: "Translation generation ##{generation.id} resumed."
    end

    def cancel_generation
      generation = generation_for_request
      authorize @language, :cancel_generation?
      TranslationGenerationService.new(generation).cancel
      redirect_to admin_language_path(@language), notice: "Translation generation ##{generation.id} cancelled."
    end

    def restore
      authorize @language, :restore?
      @language.restore!
      notify_language(current_user, @language, 'restored')
      broadcast_language_selector
      redirect_to admin_languages_path, notice: 'Language restored.'
    end

    def really_destroy
      authorize @language, :really_destroy?
      @language.really_destroy!
      redirect_to admin_languages_path, notice: 'Language permanently deleted.'
    end

    def content
      current = helpers.current_language
      render partial: 'admin/shared/language_selector_content', locals: { current: }
    end

    private

    def set_language
      @language = Language.not_deleted.find(params[:id])
    end

    def set_deleted_language
      @language = Language.with_deleted.find(params[:id])
    end

    def generation_for_request
      @language.translation_generations.find(params[:generation_id])
    end

    def language_params
      params.expect(language: %i[name code flag_iso status])
    end

    def enqueue_generation
      TranslationGeneration.enqueue_for!(@language, actor: current_user)
    end

    def notify_language(user, language, action)
      LanguageNotification.with(action: action, record: language, user: user)
                           .deliver(user, enqueue_job: false)
      user.broadcast_notifications_refresh
      broadcast_language_selector
    end

    def broadcast_language_selector
      current = helpers.current_language
      html = render_to_string(
        partial: 'admin/shared/language_selector_content',
        formats: [:html],
        locals: { current: }
      )
      Turbo::StreamsChannel.broadcast_update_to(
        'language_selector',
        target: 'language_selector_content',
        html: html
      )
    end

    def load_languages
      @languages = filter_scope(Language.available)
      @total_count = @languages.count
      @languages = apply_sorting(@languages)
      @languages = paginate(@languages)
    end

    def filter_scope(scope)
      scope = scope.where('name ILIKE :q OR code ILIKE :q', q: "%#{params[:search]}%") if params[:search].present?
      return scope unless params[:status].present? && params[:status] != 'all'

      scope.where(status: params[:status])
    end

    def apply_sorting(scope)
      sort_column = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'name'
      sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
      scope.order(sort_column => sort_direction)
    end

    def paginate(scope)
      page = [(params[:page] || 1).to_i, 1].max
      per_page = per_page_param
      @total_pages = [(scope.count / per_page.to_f).ceil, 1].max
      page = @total_pages if page > @total_pages
      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      per_page = params[:per_page]&.to_i
      PER_PAGE_OPTIONS.include?(per_page) ? per_page : PER_PAGE
    end

    def check_permissions
      return if %w[restore really_destroy].include?(action_name)

      authorize(params[:id].present? ? @language : Language)
    end

    def forbidden
      head :forbidden
    end
  end
end
