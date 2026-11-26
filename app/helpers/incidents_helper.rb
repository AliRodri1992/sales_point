module IncidentsHelper
  def report_incident_path(failure: false)
    return_path = request.path if %w[GET HEAD].include?(request.request_method)
    origin = { screen: "#{controller_path}##{action_name}", user_id: current_user.id,
               organization_id: current_organization.id, path: return_path,
               request_id: (request.request_id if failure) }
    token = Rails.application.message_verifier(:incident_origin).generate(origin, expires_in: 12.hours)
    new_admin_incident_path(origin: token)
  end

  def incident_origin_label(incident)
    mod, screen = incident.origin_screen.to_s.split('#', 2)
    return if mod.blank?

    [incident_module_label(mod), t("incidents.screens.#{screen}", default: screen.to_s.humanize)].join(' › ')
  end

  def incident_module_label(key)
    t("incidents.modules.#{key.to_s.split('/').last}", default: key.to_s.humanize)
  end
end
