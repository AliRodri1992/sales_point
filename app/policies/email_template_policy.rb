# frozen_string_literal: true

class EmailTemplatePolicy < ApplicationPolicy
  ListingSnapshot = Struct.new(:active_admin, :super_admin, :permissions, :organization_ids, keyword_init: true)

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
    allowed?('email_templates.update') && same_tenant? && record.status != 'archived'
  end

  def publish?
    allowed?('email_templates.publish') && same_tenant? && record.status != 'archived'
  end

  def archive?
    allowed?('email_templates.archive') && same_tenant? && !record.protected_global?
  end

  def destroy?
    archive? && record.status != 'archived'
  end

  def personalize?
    create? && record.organization_id.nil? && record.status == 'published' &&
      record.enabled? && record.published_version.present?
  end

  def deactivate?
    archive? && record.status == 'published' && record.enabled?
  end

  def activate?
    allowed?('email_templates.publish') && same_tenant? &&
      record.status == 'inactive' && record.published_version.present?
  end

  def reactivate?
    allowed?('email_templates.archive') && same_tenant? &&
      record.status == 'archived' && !record.protected_global?
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
    snapshot = user&.email_template_policy_snapshot
    return snapshot.active_admin && snapshot.permissions.include?(permission) if snapshot

    user&.active? && user.admin? && user.permission?(permission)
  end

  def visible_tenant?
    return true if record.organization_id.nil?

    same_tenant?
  end

  def same_tenant?
    snapshot = user&.email_template_policy_snapshot
    if record.organization_id.nil?
      return snapshot.super_admin if snapshot

      return user.role?('super_admin')
    end

    return snapshot.organization_ids.include?(record.organization_id) if snapshot

    user.organization_memberships.accessible.exists?(organization_id: record.organization_id)
  end
end
