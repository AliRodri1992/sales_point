# frozen_string_literal: true

module Admin
  class LanguagesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_language, only: %i[show edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    SORTABLE_COLUMNS = %w[name code status created_at updated_at].freeze

    def index
      load_languages
    end

    def show; end

    def new
      @language = Language.new
    end

    def edit; end

    def create
      @language = Language.new(language_params)

      if @language.save
        load_languages
        notify_language(current_user, @language, 'created')
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.languages.created') }
          format.html do
            redirect_to admin_languages_path(request.query_parameters), notice: t('admin.languages.created')
          end
        end
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @language.update(language_params)
        load_languages
        notify_language(current_user, @language, 'updated')
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.languages.updated') }
          format.html do
            redirect_to admin_languages_path(request.query_parameters), notice: t('admin.languages.updated')
          end
        end
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @language.update!(deleted_at: Time.current)
      load_languages
      notify_language(current_user, @language, 'destroyed')
      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.languages.destroyed') }
        format.html do
          redirect_to admin_languages_path(request.query_parameters), notice: t('admin.languages.destroyed')
        end
      end
    end

    def content
      current = helpers.current_language
      render partial: 'admin/shared/language_selector_content', locals: { current: }
    end

    private

    def set_language
      @language = Language.not_deleted.find(params[:id])
    end

    def language_params
      params.expect(language: %i[name code flag_iso status])
    end

    def notify_language(user, language, action)
      LanguageNotification
        .with(action: action, record: language, user: user)
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
      page = (params[:page] || 1).to_i
      page = 1 if page < 1
      per_page = per_page_param

      @total_pages = (scope.count / per_page.to_f).ceil
      @total_pages = 1 if @total_pages < 1
      page = @total_pages if page > @total_pages

      scope.limit(per_page).offset((page - 1) * per_page)
    end

    def per_page_param
      per_page = params[:per_page]&.to_i
      PER_PAGE_OPTIONS.include?(per_page) ? per_page : PER_PAGE
    end
  end
end
