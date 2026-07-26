# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    layout 'authentication'

    def new
      return redirect_to(authenticated_root_path) if user_signed_in?

      super
    end

    protected

    def after_sign_in_path_for(_resource)
      authenticated_root_path
    end

    def after_sign_out_path_for(_resource)
      new_user_session_path
    end

    private

    def redirect_authenticated_user
      redirect_to authenticated_root_path if user_signed_in?
    end
  end
end
