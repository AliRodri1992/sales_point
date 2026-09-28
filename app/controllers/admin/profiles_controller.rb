# frozen_string_literal: true

module Admin
  class ProfilesController < ApplicationController
    layout 'admin_dashboard'

    before_action :authenticate_user!

    def show
      @profile = current_user
      load_form_options
    end

    def update
      @profile = current_user

      if @profile.update(profile_params)
        redirect_to admin_profile_path, notice: t('.success')
      else
        load_form_options
        render :show, status: :unprocessable_content
      end
    end

    private

    def profile_params
      params.expect(profile: %i[username email language_id theme])
    end

    def load_form_options
      @languages = Language.available.order(:name)
      @themes = Theme.all
      @roles = current_user.system_roles.active.order(:name)
    end
  end
end
