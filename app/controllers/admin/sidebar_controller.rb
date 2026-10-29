module Admin
  class SidebarController < ApplicationController
    before_action :authenticate_user!

    def update
      # Saving a UI preference must not depend on unrelated profile validations.
      current_user.update_column(
        :sidebar_collapsed, ActiveModel::Type::Boolean.new.cast(params[:sidebar_collapsed])
      )

      head :ok
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: [e.message] }, status: :unprocessable_content
    end
  end
end
