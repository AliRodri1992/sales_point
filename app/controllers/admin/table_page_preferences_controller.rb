# frozen_string_literal: true

module Admin
  class TablePagePreferencesController < ApplicationController
    before_action :authenticate_user!

    def update
      return head :forbidden unless current_organization

      key, size = preference_input
      return head :unprocessable_content unless valid_preference?(key, size)

      preference = current_user.table_page_preferences.active_records.find_or_initialize_by(
        organization: current_organization, table_key: key
      )
      preference.update!(per_page: size.to_i)
      head :no_content
    end

    private

    def preference_input
      [params[:table_key].to_s, params[:per_page].to_s]
    end

    def valid_preference?(key, size)
      TablePagePreference::TABLE_KEYS.include?(key) &&
        TablePagePreference::OPTIONS.map(&:to_s).include?(size)
    end
  end
end
