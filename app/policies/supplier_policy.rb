# frozen_string_literal: true

class SupplierPolicy
  attr_reader :user, :supplier

  def initialize(user, supplier)
    @user = user
    @supplier = supplier
  end

  def index? = authorized_organization?
  def show? = authorized_record?
  def new? = authorized_record?
  def create? = authorized_record?
  def edit? = authorized_record?
  def update? = authorized_record?
  def destroy? = authorized_record?

  private

  def authorized_organization?
    user&.admin? && user.organizations.active_records.exists?
  end

  def authorized_record?
    user&.admin? && supplier.organization_id.present? &&
      user.organizations.active_records.exists?(id: supplier.organization_id)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return @scope.none unless @user&.admin?

      @scope.where(organization_id: @user.organizations.active_records.select(:id))
    end
  end
end
