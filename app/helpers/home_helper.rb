module HomeHelper
  def landing_primary_action_text
    user_signed_in? ? t('landing.buttons.dashboard') : t('landing.buttons.start')
  end

  def landing_primary_action_path
    user_signed_in? ? admin_dashboard_path : new_user_registration_path
  end
end
