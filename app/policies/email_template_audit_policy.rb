# frozen_string_literal: true

class EmailTemplateAuditPolicy < ApplicationPolicy
  def index?
    user&.active? && user.admin? && user.permission?('email_template_audits.view')
  end
end
