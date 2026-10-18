# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rack::Attack do
  let(:app) { ->(_env) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }
  let(:client) { Rack::MockRequest.new(described_class.new(app)) }
  let(:ip) { '203.0.113.8' }

  around do |example|
    previous_store = described_class.cache.store
    previous_enabled = described_class.enabled
    described_class.cache.store = ActiveSupport::Cache::MemoryStore.new
    described_class.enabled = true
    example.run
  ensure
    described_class.cache.store = previous_store
    described_class.enabled = previous_enabled
  end

  def request(path, method: :get, user_id: nil, address: ip)
    warden = user_id && double('warden', user: Struct.new(:id).new(user_id))
    env = { 'REMOTE_ADDR' => address }
    env['warden'] = warden if warden
    client.request(method, path, env).status
  end

  it 'permits 120 admin requests per authenticated user without sharing a quota across coworkers' do
    120.times { expect(request('/admin/suppliers', user_id: 10)).to eq(200) }

    expect(request('/admin/suppliers', user_id: 10)).to eq(429)
    expect(request('/admin/suppliers', user_id: 20)).to eq(200)
  end

  it 'uses IP fallback for anonymous administrative requests' do
    120.times { expect(request('/admin/suppliers')).to eq(200) }

    expect(request('/admin/suppliers')).to eq(429)
    expect(request('/admin/suppliers', address: '203.0.113.9')).to eq(200)
  end

  it 'permits 20 geocoding requests per minute independently of normal admin activity' do
    path = '/admin/suppliers/1/address_location_suggestion'
    20.times { expect(request(path, method: :post, user_id: 10)).to eq(200) }

    expect(request(path, method: :post, user_id: 10)).to eq(429)
    expect(request('/admin/suppliers', user_id: 10)).to eq(200)
  end

  it 'permits 120 map requests per minute' do
    path = '/admin/suppliers/1/address_map'
    120.times { expect(request(path, user_id: 10)).to eq(200) }

    expect(request(path, user_id: 10)).to eq(429)
    expect(request('/admin/suppliers', user_id: 10)).to eq(200)
  end

  it 'keeps login attempts limited to five per minute' do
    5.times { expect(request('/users/sign_in', method: :post)).to eq(200) }

    expect(request('/users/sign_in', method: :post)).to eq(429)
  end

  it 'retains a global rate limit of 1,200 requests per IP within five minutes' do
    1_200.times { expect(request('/up')).to eq(200) }

    expect(request('/up')).to eq(429)
    expect(request('/up', address: '203.0.113.9')).to eq(200)
  end

  it 'places Rack::Attack after Warden to enable user-scoped discrimination' do
    middlewares = Rails.application.middleware.map(&:klass)
    expect(middlewares.index(described_class)).to be > middlewares.index(Warden::Manager)
  end
end
