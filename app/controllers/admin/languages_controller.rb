# frozen_string_literal: true

module Admin
  class LanguagesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_language, only: %i[show edit update destroy]

    def index
      @languages = Language.not_deleted.order(:name)
    end

    def show; end

    def new
      @language = Language.new
    end

    def edit; end

    def create
      @language = Language.new(language_params)

      if @language.save
        @languages = Language.not_deleted.order(:name)
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.languages.created') }
          format.html { redirect_to admin_languages_path, notice: t('admin.languages.created') }
        end
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @language.update(language_params)
        @languages = Language.not_deleted.order(:name)
        respond_to do |format|
          format.turbo_stream { @swal_message = t('admin.languages.updated') }
          format.html { redirect_to admin_languages_path, notice: t('admin.languages.updated') }
        end
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @language.update!(deleted_at: Time.current)
      @languages = Language.not_deleted.order(:name)
      respond_to do |format|
        format.turbo_stream { @swal_message = t('admin.languages.destroyed') }
        format.html { redirect_to admin_languages_path, notice: t('admin.languages.destroyed') }
      end
    end

    private

    def set_language
      @language = Language.not_deleted.find(params[:id])
    end

    def language_params
      params.expect(language: %i[name code flag_iso status])
    end
  end
end
