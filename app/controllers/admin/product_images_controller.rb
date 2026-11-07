# frozen_string_literal: true

module Admin
  class ProductImagesController < ApplicationController
    before_action :authenticate_user!

    def create
      raise ActiveRecord::RecordNotFound unless current_organization

      authorize_upload
      blob = Products::ImageUpload.call(file: params[:file], organization: current_organization, user: current_user)
      token = Products::ImageUpload.token(blob, organization: current_organization, user: current_user)
      render json: { signed_id: token, filename: blob.filename.to_s }, status: :created
    rescue ArgumentError
      render json: { error: t('admin.catalog_design.image_upload_error') }, status: :unprocessable_content
    end

    private

    def authorize_upload
      if params[:product_id].present?
        product = current_organization.products.not_deleted.find(params[:product_id])
        authorize product, :update?
      else
        authorize Product, :create?
      end
    end
  end
end
