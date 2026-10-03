# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      build_resource(sign_up_params)
      result = RegistrationService.call(resource:, params: registration_params)

      return complete_sign_up if result.success?

      render_registration_error
    end

    protected

    def sign_up_params
      devise_parameter_sanitizer.sanitize(:sign_up)
    end

    def registration_params
      params.permit(
        :setup_type, :first_name, :last_name, :company_name, :tax_id,
        :business_sector, :migration_volume, :migration_priority,
        :branches, :currency, :terminals, :payment_integration, :terms
      )
    end

    def complete_sign_up
      flash[:swal_message] = t('devise.registrations.signed_up')
      sign_up(resource_name, resource)
      respond_with resource, location: after_sign_up_path_for(resource)
    end

    def render_registration_error
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource, status: :unprocessable_content
    end

    def after_sign_up_path_for(_resource)
      admin_onboarding_path
    end
  end
end
