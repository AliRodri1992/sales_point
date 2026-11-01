# frozen_string_literal: true

module Admin
  class AssistantController < ApplicationController
    before_action :authenticate_user!

    def reply
      message = params[:message].to_s.strip
      if message.blank? || message.length > 500
        return render json: { error: t('admin.assistant.invalid_question') },
                      status: :unprocessable_content
      end

      response.headers['Cache-Control'] = 'no-store'
      result = Assistant::GuideResponder.new(
        user: current_user, organization: current_organization
      ).call(question: message, context: params[:context].to_s)

      render json: result
    end
  end
end
