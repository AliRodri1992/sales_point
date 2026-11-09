# frozen_string_literal: true

module Admin
  class LanguagesController < ApplicationController
    include Admin::LanguagesListing

    layout 'admin_dashboard'
    before_action :authenticate_user!
    include CatalogAuthorization
    include CatalogNavigation

    before_action :set_language, only: %i[show edit update destroy]

    PER_PAGE = 10
    PER_PAGE_OPTIONS = TablePagePreference::OPTIONS

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
        return if redirect_without_catalog_listing(@language, :created)

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
        return if redirect_without_catalog_listing(@language, :updated)

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
      return redirect_destroy_failure unless @language.update(deleted_at: Time.current)
      load_languages
      notify_language(current_user, @language, 'destroyed')
      return if redirect_without_catalog_listing(@language, :destroyed)

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

    def redirect_destroy_failure
      redirect_to admin_languages_path,
                  alert: @language.errors.full_messages.to_sentence,
                  status: :see_other
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
  end
end
