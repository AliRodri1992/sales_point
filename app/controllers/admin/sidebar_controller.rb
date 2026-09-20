module Admin
  class SidebarController < ApplicationController
    before_action :authenticate_user!

    def update
      current_user.update!(
        sidebar_collapsed: ActiveModel::Type::Boolean.new.cast(params[:sidebar_collapsed])
      )

      head :ok
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: [e.message] }, status: :unprocessable_content
    end
  end
end
