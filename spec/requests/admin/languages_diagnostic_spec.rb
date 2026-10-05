require 'rails_helper'

RSpec.describe 'Admin::Languages Diagnostic', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:user) { create(:user, status: 'active') }

  before do
    sign_in user
  end

  it 'create response body contains swal toast' do
    post admin_languages_path(format: :turbo_stream),
         params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'active' } }

    puts '=== CREATE RESPONSE BODY ==='
    puts response.body
    puts '=== END ==='
    expect(response.body).to include('action="swal"')
  end

  it 'create stores user param' do
    post admin_languages_path(format: :turbo_stream),
         params: { language: { name: 'Test Language', code: 'tl', flag_iso: 'tl', status: 'active' } }

    notification = Noticed::Notification.last
    puts '=== CREATE PARAMS ==='
    puts "action: #{notification.params[:action].inspect}"
    puts "user: #{notification.params[:user].inspect}"
    puts "user class: #{notification.params[:user]&.class}"
    puts '=== END ==='
  end

  it 'destroy response body contains swal toast' do
    language = create(:language, name: 'ToDelete', code: 'td', flag_iso: 'td')
    delete admin_language_path(language, format: :turbo_stream)

    puts '=== DESTROY RESPONSE BODY ==='
    puts response.body
    puts '=== END ==='
    expect(response.body).to include('action="swal"')
  end

  it 'destroy stores user param' do
    language = create(:language, name: 'ToDelete', code: 'td', flag_iso: 'td')
    delete admin_language_path(language, format: :turbo_stream)

    notification = Noticed::Notification.last
    puts '=== DESTROY PARAMS ==='
    puts "action: #{notification.params[:action].inspect}"
    puts "user: #{notification.params[:user].inspect}"
    puts "user class: #{notification.params[:user]&.class}"
    puts "record: #{notification.record.inspect}"
    puts "record class: #{notification.record&.class}"
    puts '=== END ==='
  end
end
