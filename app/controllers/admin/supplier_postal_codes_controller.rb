# frozen_string_literal: true

module Admin
  class SupplierPostalCodesController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_supplier
    before_action :validate_postal_query

    def show
      suggestion = Suppliers::MexicanPostalLookup.new(params[:postal_code]).call
      return head :service_unavailable unless suggestion

      response.headers['Cache-Control'] = 'private, no-store'
      render json: suggestion
    end

    private

    def authorize_supplier
      return head :forbidden unless current_organization

      if params[:id].present?
        supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:id])
        authorize supplier, :manage_addresses?
      else
        authorize current_organization.suppliers.new, :create?
      end
    end

    def validate_postal_query
      valid = params[:country] == 'MX' && /\A\d{5}\z/.match?(params[:postal_code].to_s)
      head :unprocessable_content unless valid
    end
  end
end
