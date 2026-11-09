# frozen_string_literal: true

# Isolates the selected tenant during permission checks within a request.
class CurrentOrganizationAccess < ActiveSupport::CurrentAttributes
  attribute :organization, :enforce_tenant
end
