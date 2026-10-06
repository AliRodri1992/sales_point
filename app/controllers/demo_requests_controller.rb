# frozen_string_literal: true

class DemoRequestsController < ApplicationController
  def new
    @demo_request = DemoRequest.new
  end

  def create
    @demo_request = DemoRequest.new(demo_request_params)

    if @demo_request.save
      DemoRequestMailer
        .with(demo_request: @demo_request, locale: I18n.locale.to_s)
        .confirmation
        .deliver_later

      redirect_to new_demo_request_path, notice: t('.success')
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def demo_request_params
    permitted = params.expect(
      demo_request: %i[name email phone phone_full company business_type branches message terms_accepted]
    )
    permitted[:phone] = permitted.delete(:phone_full).presence || permitted[:phone]
    permitted
  end
end
