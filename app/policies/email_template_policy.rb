# frozen_string_literal: true

class EmailTemplatePolicy < ApplicationPolicy
  def index?
    allowed?('email_templates.access')
  end

  def show?
    index? && visible_tenant?
  end

  def create?
    allowed?('email_templates.create')
  end

  def update?
    allowed?('email_templates.update') && same_tenant?
  end

  def publish?
    allowed?('email_templates.publish') && same_tenant?
  end

  def archive?
    allowed?('email_templates.archive') && same_tenant?
  end

  def preview?
    allowed?('email_templates.preview') && visible_tenant?
  end

  def send_test?
    allowed?('email_templates.send_test') && same_tenant?
  end

  def versions?
    allowed?('email_templates.versions') && visible_tenant?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      ids = user.organization_memberships.accessible.select(:organization_id)
      scope.where(organization_id: ids).or(scope.where(organization_id: nil))
    end
  end

  private

  def allowed?(permission)
    user&.active? && user.admin? && user.permission?(permission)
  end

  def visible_tenant?
    return true if record.organization_id.nil?

    same_tenant?
  end

  def same_tenant?
    return user.role?('super_admin') if record.organization_id.nil?
    user.organization_memberships.accessible.exists?(organization_id: record.organization_id)
  end
end
