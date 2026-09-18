# frozen_string_literal: true

class SystemRolesController < ApplicationController
  before_action :set_system_role, only: %i[show destroy]

  def index
    @system_roles = SystemRole.order(:name)
  end

  def show; end

  def new
    @system_role = SystemRole.new
  end

  def create
    @system_role = SystemRole.new(system_role_params)

    if @system_role.save
      redirect_to system_roles_path, notice: t('.success')
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    @system_role.destroy!
    redirect_to system_roles_path, notice: t('.success')
  end

  private

  def set_system_role
    @system_role = SystemRole.find(params[:id])
  end

  def system_role_params
    params.expect(system_role: %i[name code role_type status description])
  end
end
