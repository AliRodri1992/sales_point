# frozen_string_literal: true

module PortalStrategies
  class DeltaPortalStrategy < Base
    def path
      Rails.application.routes.url_helpers.dashboard_path
    end
  end
end
