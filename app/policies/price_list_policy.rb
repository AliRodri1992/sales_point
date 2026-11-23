# frozen_string_literal: true

class PriceListPolicy < CommercialPolicy
  self.permission_prefix = 'price_lists'

  def view_margin? = permitted_action?(:view_margin)
  def authorize_below_cost? = permitted_action?(:authorize_below_cost)
  alias below_cost? authorize_below_cost?
end
