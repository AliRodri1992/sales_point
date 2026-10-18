# frozen_string_literal: true

module Admin
  class SupplierPostalCodesController < ApplicationController
    before_action :authenticate_user!

    def show
      return head :forbidden unless current_organization

      supplier = policy_scope(current_organization.suppliers.not_deleted).find(params[:id])
      authorize supplier, :manage_addresses?
      return head :unprocessable_content unless params[:country] == 'MX'
      return head :unprocessable_content unless /\A\d{5}\z/.match?(params[:postal_code].to_s)

      suggestion = Suppliers::MexicanPostalLookup.new(params[:postal_code]).call
      return head :service_unavailable unless suggestion

      response.headers['Cache-Control'] = 'private, no-store'
      render json: suggestion
    end
  end
end
