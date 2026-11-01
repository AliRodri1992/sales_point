# frozen_string_literal: true

module Admin
  class TablePagePreferencesController < ApplicationController
    before_action :authenticate_user!

    def update
      return head :forbidden unless current_organization

      key = params[:table_key].to_s
      size = params[:per_page].to_s
      unless TablePagePreference::TABLE_KEYS.include?(key) &&
             TablePagePreference::OPTIONS.map(&:to_s).include?(size)
        return head :unprocessable_content
      end

      preference = current_user.table_page_preferences.find_or_initialize_by(
        organization: current_organization, table_key: key
      )
      preference.update!(per_page: size.to_i)
      head :no_content
    end
  end
end
