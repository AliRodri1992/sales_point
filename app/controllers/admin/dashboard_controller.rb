module Admin
  class DashboardController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!

    def index
      @dashboard_preferences = current_user.dashboard_preferences.map do |preference|
        {
          grid_type: preference.grid_type,
          widget_id: preference.widget_id,
          x: preference.position_x,
          y: preference.position_y,
          w: preference.width,
          h: preference.height
        }
      end
    end

    def save_preferences
      DashboardPreference.transaction do
        dashboard_preferences_params.each do |widget|
          save_widget_preference(widget)
        end
      end

      render json: { success: true }
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        success: false,
        errors: [e.message]
      }, status: :unprocessable_content
    end

    private

    def save_widget_preference(widget)
      preference = current_user.dashboard_preferences.find_or_initialize_by(
        widget_id: widget[:widget_id]
      )

      preference.assign_attributes(
        position_x: widget[:x],
        position_y: widget[:y],
        width: widget[:w],
        height: widget[:h]
      )

      preference.save!
    end

    def dashboard_preferences_params
      params.require(:widgets).map do |widget|
        widget.permit(
          :grid_type,
          :widget_id,
          :x,
          :y,
          :w,
          :h
        ).to_h.symbolize_keys
      end
    end
  end
end
