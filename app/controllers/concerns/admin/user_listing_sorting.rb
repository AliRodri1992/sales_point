# frozen_string_literal: true

module Admin
  # Applies the user-directory sort order, including organization-local status.
  module UserListingSorting
    private

    def apply_sorting(scope)
      column = self.class::SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : 'users.email'
      direction = self.class::SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'
      return scope.order(column => direction) unless column == 'users.status'

      order_by_membership_status(scope, direction)
    end

    def order_by_membership_status(scope, direction)
      scope.joins(:organization_memberships)
           .where(organization_memberships: { organization_id: current_organization.id,
                                              status: 'active', deleted_at: nil })
           .order(Arel.sql("organization_memberships.account_status #{direction.upcase}"))
           .order('users.id': :asc)
    end
  end
end
