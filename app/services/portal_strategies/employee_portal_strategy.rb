# frozen_string_literal: true

module PortalStrategies
  class EmployeePortalStrategy < Base
    def path
      Rails.application.routes.url_helpers.admin_dashboard_path
    end
  end
end
