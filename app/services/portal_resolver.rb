# frozen_string_literal: true

class PortalResolver
  STRATEGIES = {
    'delta' => PortalStrategies::DeltaPortalStrategy,
    'employee' => PortalStrategies::EmployeePortalStrategy
  }.freeze

  def initialize(user)
    @user = user
  end

  def path
    strategy.new.path
  end

  private

  attr_reader :user

  def strategy
    STRATEGIES.fetch(user.user_type) { raise PortalAccessDeniedError }
  end
end
