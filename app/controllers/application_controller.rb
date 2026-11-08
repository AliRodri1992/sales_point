class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include OrganizationTimeZone
  include TablePageSizing

  allow_browser versions: :modern

  around_action :with_organization_timezone
  before_action :set_locale
  before_action :enforce_active_account
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :set_action_cable_user_id_cookie

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  helper_method :current_language, :current_organization, :available_organizations,
                :available_branches, :current_branch

  def available_organizations
    return Organization.none unless current_user

    @available_organizations ||= Organization.active_records.where(
      id: current_user.organization_memberships.accessible.select(:organization_id)
    ).order(:id)
  end

  def current_organization
    return unless current_user

    @current_organization ||= available_organizations.find_by(id: session[:current_organization_id]) ||
                              available_organizations.first
  end

  def available_branches
    return Branch.none unless current_organization

    @available_branches ||= begin
      branches = current_organization.branches.not_deleted.where(operational_status: 'active')

      unless current_user.admin?
        assigned_branch_ids = current_user.user_roles.active.where.not(branch_id: nil).select(:branch_id)
        branches = branches.where(id: assigned_branch_ids)
      end

      branches.order(:name)
    end
  end

  def current_branch
    return unless current_organization

    branch = available_branches.find_by(id: session[:current_branch_id])
    branch || available_branches.first
  end

  private

  def enforce_active_account
    return unless user_signed_in?
    return if current_user.active? && current_user.deleted_at.nil? && session_not_revoked?

    sign_out(current_user)
    cookies.delete(:user_id)
    redirect_to new_user_session_path
  end

  def session_not_revoked?
    revoked_at = current_user.session_revoked_at
    return true unless revoked_at

    issued_at = session[:user_session_issued_at]
    issued_at.present? && issued_at.to_f > revoked_at.to_f
  end

  def with_organization_timezone(&)
    settings = current_organization&.organization_settings&.active_records
    zone = settings&.first&.timezone
    timezone = ActiveSupport::TimeZone[zone] if zone.present?
    Time.use_zone(timezone || Time.zone, &)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[email password password_confirmation theme])
  end

  def set_action_cable_user_id_cookie
    return unless user_signed_in?

    payload = cookies.signed[:user_id]
    return if payload.is_a?(Hash) && payload['id'] == current_user.id &&
              payload['issued_at'] == session[:user_session_issued_at]

    cookies.signed[:user_id] = {
      value: { id: current_user.id, issued_at: session[:user_session_issued_at] },
      httponly: true,
      same_site: :lax
    }
  end

  def set_locale
    locale = preferred_locale || fallback_locale
    I18n.locale = locale if I18n.available_locales.include?(locale)
  end

  def preferred_locale
    user_language_code || session_language_code || cookie_language_code
  end

  def cookie_language_code
    code = cookies[:terminal_language].presence
    return unless code

    Language.selectable.find_by(code: code.downcase)&.code&.to_sym
  end

  def user_language_code
    user = current_user || request.env['warden']&.user
    language = user&.language
    return unless language&.active? && language.deleted_at.nil?

    code = language.code.downcase.to_sym
    code if I18n.available_locales.include?(code)
  end

  def session_language_code
    language = Language.selectable.find_by(id: session[:language_id])
    return unless language

    language.code.downcase.to_sym
  end

  def fallback_locale
    language = Language.selectable.find_by(code: I18n.default_locale.to_s) || Language.selectable.first
    language&.code&.to_sym || I18n.default_locale
  end

  def current_language
    Language.selectable.find_by(code: I18n.locale.to_s) || Language.selectable.first
  end

  def forbidden
    head :forbidden
  end
end
