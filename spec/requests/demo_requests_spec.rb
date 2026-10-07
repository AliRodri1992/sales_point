# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Demo requests', type: :request do
  before do
    create(:language, :english) if Language.where(code: 'en').empty?
    notification = instance_double(DemoRequestNotification, deliver: true)
    allow(DemoRequestNotification).to receive(:with).and_return(notification)

    message_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    mailer_double = double('mailer_double', confirmation: message_delivery)
    allow(DemoRequestMailer).to receive(:with).and_return(mailer_double)
  end

  describe 'GET /demo_requests/new' do
    it 'renders the redesigned request form' do
      get new_demo_request_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('demo-request-page')
      expect(response.body).to include('demo-request-wizard')
    end
  end

  describe 'POST /demo_requests' do
    it 'creates a demo request and redirects with a success message' do
      expect do
        post demo_requests_path, params: {
          demo_request: attributes_for(:demo_request)
        }
      end.to change(DemoRequest, :count).by(1)

      expect(DemoRequest.last.activities.where(action: 'created')).to exist
      expect(response).to redirect_to(new_demo_request_path)
      follow_redirect!
      expect(response.body).to include(I18n.t('demo_requests.create.success'))
    end

    it 'renders the form when the request is invalid' do
      post demo_requests_path, params: {
        demo_request: {
          name: '',
          email: 'invalid',
          company: '',
          phone: '123'
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t('demo_requests.new.error_summary', count: 5))
    end
  end
end
