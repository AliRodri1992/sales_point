# frozen_string_literal: true

# Publish the canonical invitation for all supported locales. Existing organization
# overrides and edited/published templates are never replaced by this seed.
EmailTemplates::InvitationContent.ensure_published!
