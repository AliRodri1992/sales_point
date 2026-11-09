# frozen_string_literal: true

module Admin
  class GeneralSettingsController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_admin!

    def show
      load_settings
    end

    def update
      load_settings
      return if performed?

      @recovering_settings ? recover_settings : update_preference
      return render :show, status: (@stale_preference ? :conflict : :unprocessable_content) if @settings.errors.any?

      if @updated
        key = @recovering_settings ? 'created' : 'saved'
        redirect_to admin_general_settings_path, flash: { swal_message: t("admin.general_settings.#{key}") }
      else
        redirect_to admin_general_settings_path
      end
    end

    private

    def require_admin!
      head :forbidden unless current_user.admin? && current_organization
    end

    def load_settings
      scope = current_organization.organization_settings
      @settings = scope.active_records.first
      return if @settings

      return head :not_found if scope.with_deleted.exists?

      @recovering_settings = true
      @settings = scope.build(default_table_page_size: TablePagePreference::DEFAULT)
      @currencies = Currency.active.order(:code)
    end

    def update_preference
      @settings.with_lock do
        if stale_preference?
          @stale_preference = true
          @settings.errors.add(:default_table_page_size, t('admin.general_settings.stale_message'))
          next
        end

        previous_size = @settings.default_table_page_size
        @settings.assign_attributes(settings_params)
        next unless @settings.save(context: :general_settings)
        next if previous_size == @settings.default_table_page_size

        audit_preference_change(previous_size)
      end
    end

    def audit_preference_change(previous_size)
      GeneralSettingAuditEvent.create!(
        organization: current_organization, actor: current_user,
        previous_page_size: previous_size, new_page_size: @settings.default_table_page_size
      )
      @updated = true
    end

    def recover_settings
      @settings.assign_attributes(recovery_params)

      current_organization.with_lock do
        if current_organization.organization_settings.with_deleted.exists?
          @stale_preference = true
          @settings.errors.add(:base_currency, t('admin.general_settings.recovery_conflict'))
        else
          @updated = @settings.save
        end
      end
    end

    def stale_preference?
      expected = params[:expected_settings_updated_at].presence
      expected.nil? || expected.to_s != @settings.updated_at.utc.iso8601(6)
    end

    def settings_params
      params.expect(organization_setting: [:default_table_page_size])
    end

    def recovery_params
      params.expect(organization_setting: %i[base_currency_id timezone payment_method default_table_page_size])
    end
  end
end
