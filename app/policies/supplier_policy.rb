# frozen_string_literal: true

class SupplierPolicy
  attr_reader :user, :supplier

  def initialize(user, supplier)
    @user = user
    @supplier = supplier
  end

  def index? = user&.admin?
  def show? = user&.admin?
  def new? = user&.admin?
  def create? = user&.admin?
  def edit? = user&.admin?
  def update? = user&.admin?
  def destroy? = user&.admin?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      @user&.admin? ? @scope : @scope.none
    end
  end
end
