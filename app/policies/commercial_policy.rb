# frozen_string_literal: true

class CommercialPolicy < CatalogPolicy
  def access?
    return false unless user && organization
    return @access if defined?(@access)

    @access = administrator? || granted?(:access)
  end

  def archive? = permitted_action?(:archive)
  def destroy? = archive?
  def activate? = permitted_action?(:activate)
  def pause? = permitted_action?(:pause)
  def resume? = permitted_action?(:resume)
  def duplicate? = permitted_action?(:duplicate)
  def history? = permitted_action?(:history)

  private

  def permitted_action?(action)
    access? && (administrator? || granted?(action))
  end

  def granted?(action)
    user.permission?("#{permission_prefix}.#{action}", organization:)
  end

  def administrator?
    return @administrator if defined?(@administrator)

    @administrator = CurrentOrganizationAccess.set(organization:) { user.admin? }
  end

  def organization
    return @organization if defined?(@organization)

    current = CurrentOrganizationAccess.organization
    @organization = current || standalone_organization
    @organization = nil if @organization && record.respond_to?(:organization_id) &&
                           record.organization_id != @organization.id
    @organization
  end

  def standalone_organization
    return if CurrentOrganizationAccess.enforce_tenant || !record.respond_to?(:organization)

    record.organization
  end
end
