# frozen_string_literal: true

module Admin
  class UnitsOfMeasureController < ApplicationController
    include Admin::UnitsOfMeasureListing

    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :require_organization
    before_action :authorize_unit_of_measure
    before_action :set_unit, only: %i[show edit update destroy]
    before_action :load_sat_keys, only: %i[new edit create update]

    def index
      load_units
    end

    def show; end

    def new
      @unit = UnitOfMeasure.new
    end

    def edit; end

    def create
      @unit = UnitOfMeasure.new(unit_params.merge(organization: current_organization))
      return invalid_unit(:new) unless @unit.save

      saved_unit(:created)
    rescue ActiveRecord::RecordNotUnique
      @unit.errors.add(:code, :taken)
      invalid_unit(:new)
    end

    def update
      return invalid_unit(:edit) unless @unit.update(unit_params)

      saved_unit(:updated)
    rescue ActiveRecord::RecordNotUnique
      @unit.errors.add(:code, :taken)
      invalid_unit(:edit)
    end

    def destroy
      @unit.update!(deleted_at: Time.current)
      saved_unit(:destroyed)
    end

    private

    def require_organization
      head :forbidden unless current_organization
    end

    def authorize_unit_of_measure
      authorize UnitOfMeasure
    end

    def set_unit
      @unit = scoped_units.find(params[:id])
    end

    def scoped_units
      UnitOfMeasure.not_deleted.for_organization(current_organization)
    end

    def unit_params
      params.expect(unit_of_measure: %i[code name abbreviation description sat_unit_key_id
                                        decimal_precision status])
    end

    def load_sat_keys
      @sat_keys = SatUnitKey.current.order(:code).to_a
      return unless @unit&.sat_unit_key && @sat_keys.exclude?(@unit.sat_unit_key)

      @sat_keys.unshift(@unit.sat_unit_key)
    end

    def invalid_unit(template)
      load_sat_keys
      render template, status: :unprocessable_content
    end

    def saved_unit(action)
      load_units
      respond_to do |format|
        format.turbo_stream { @swal_message = t("admin.units_of_measure.messages.#{action}") }
        format.html do
          redirect_to admin_units_of_measure_path, notice: t("admin.units_of_measure.messages.#{action}"),
                                                   status: :see_other
        end
      end
    end
  end
end
