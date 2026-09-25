# frozen_string_literal: true

module Admin
  class BranchesController < ApplicationController
    layout 'admin_dashboard'
    before_action :authenticate_user!
    before_action :set_branch, only: %i[edit update destroy]

    def index
      @branches = Branch.where(deleted_at: nil).order(:name)
      @branch = Branch.new
    end

    def create
      @branch = Branch.new(branch_params)

      if @branch.save
        redirect_to admin_branches_path, notice: 'Sucursal creada correctamente.'
      else
        @branches = Branch.where(deleted_at: nil).order(:name)
        render :index, status: :unprocessable_content
      end
    end

    def update
      if @branch.update(branch_params)
        redirect_to admin_branches_path, notice: 'Sucursal actualizada correctamente.'
      else
        @branches = Branch.where(deleted_at: nil).order(:name)
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      @branch.update!(deleted_at: Time.current)
      redirect_to admin_branches_path, notice: 'Sucursal eliminada correctamente.'
    end

    private

    def set_branch
      @branch = Branch.where(deleted_at: nil).find(params[:id])
    end

    def branch_params
      params.expect(branch: %i[name phone address status])
    end
  end
end
