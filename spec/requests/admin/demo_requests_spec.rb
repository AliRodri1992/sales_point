# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin demo requests', type: :request do
  let(:admin) { create(:user) }
  let(:demo_request) { create(:demo_request) }

  before do
    role = create(:system_role, :system, code: 'administrator')
    create(:user_role, user: admin, system_role: role)
    sign_in admin
  end

  describe 'GET /admin/demo_requests' do
    it 'lists demo requests' do
      demo_request

      get admin_demo_requests_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(demo_request.name, demo_request.company)
    end

    it 'filters by status' do
      demo_request.update!(status: :contacted)
      create(:demo_request, status: :pending)

      get admin_demo_requests_path, params: { status: 'contacted' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(demo_request.name)
      expect(response.body).not_to include('Test User')
    end
  end

  describe 'GET /admin/demo_requests/:id' do
    it 'shows the request and activity history' do
      demo_request.activities.create!(action: 'created', details: 'Request created')

      get admin_demo_request_path(demo_request)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(demo_request.name, 'Request created')
    end
  end

  describe 'PATCH /admin/demo_requests/:id' do
    it 'updates status and records the change' do
      patch admin_demo_request_path(demo_request), params: {
        demo_request: { status: 'scheduled', scheduled_at: 2.hours.from_now }
      }

      expect(response).to redirect_to(admin_demo_request_path(demo_request))
      expect(demo_request.reload.status).to eq('scheduled')
      expect(demo_request.activities.where(action: 'status_changed')).to exist
      expect(demo_request.activities.where(action: 'confirmation_sent')).to exist
    end

    it 'adds an internal note' do
      patch admin_demo_request_path(demo_request), params: {
        demo_request: { note: 'Call the prospect tomorrow morning.' }
      }

      expect(response).to redirect_to(admin_demo_request_path(demo_request))
      expect(demo_request.reload.activities.where(action: 'note_added', details: 'Call the prospect tomorrow morning.')).to exist
    end

    it 'records a contact and follow-up' do
      follow_up_at = 2.days.from_now.change(sec: 0)

      patch admin_demo_request_path(demo_request), params: {
        demo_request: {
          contacted_at: Time.current,
          contact_channel: 'whatsapp',
          contact_outcome: 'interested',
          next_follow_up_at: follow_up_at,
          next_action: 'Enviar cotización'
        }
      }

      expect(response).to redirect_to(admin_demo_request_path(demo_request))
      demo_request.reload
      expect(demo_request.contact_channel).to eq('whatsapp')
      expect(demo_request.contact_outcome).to eq('interested')
      expect(demo_request.activities.where(action: 'contact_registered')).to exist
      expect(demo_request.activities.where(action: 'follow_up_scheduled')).to exist
    end

    it 'records the demo outcome' do
      patch admin_demo_request_path(demo_request), params: {
        demo_request: { demo_outcome: 'very_interested' }
      }

      expect(response).to redirect_to(admin_demo_request_path(demo_request))
      expect(demo_request.reload.activities.where(action: 'demo_outcome_recorded')).to exist
    end

    it 'records conversion activity' do
      patch admin_demo_request_path(demo_request), params: {
        demo_request: { status: 'converted' }
      }

      expect(response).to redirect_to(admin_demo_request_path(demo_request))
      expect(demo_request.reload.converted_at).to be_present
      expect(demo_request.activities.where(action: 'converted')).to exist
    end

    it 'rejects scheduling without a date' do
      patch admin_demo_request_path(demo_request), params: {
        demo_request: { status: 'scheduled' }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(demo_request.reload.status).to eq('pending')
    end

    it 'assigns a responsible user and records the change' do
      assignee = create(:user)

      patch admin_demo_request_path(demo_request), params: {
        demo_request: { assigned_to_id: assignee.id }
      }

      expect(response).to redirect_to(admin_demo_request_path(demo_request))
      expect(demo_request.reload.assigned_to).to eq(assignee)
      expect(demo_request.activities.where(action: 'assigned')).to exist
    end
  end
end
