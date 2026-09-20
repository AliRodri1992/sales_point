# frozen_string_literal: true

class DemoRequestsController < ApplicationController
  def new
    @demo_request = DemoRequest.new
  end

  def create
    @demo_request = DemoRequest.new(demo_request_params)

    if @demo_request.save
      redirect_to new_demo_request_path, notice: t('.success')
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def demo_request_params
    params.expect(demo_request: %i[name email phone company message])
  end
end
