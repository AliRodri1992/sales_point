require 'rails_helper'
RSpec.describe 'LngSwitchProbe', type: :request do
  before do
    %w[es en ko].each do |c|
      Language.find_or_create_by(code: c) do |l|
        l.name = c.upcase
        l.flag_iso = c == 'es' ? 'es' : 'us'
        l.status = 'active'
      end
    end
  end
  it 'browser flow locale switch' do
    get '/home/index'
    puts "GET1 status=#{response.status} I18n.locale=#{I18n.locale} session_lang=#{session[:language_id].inspect}"
    puts "navbar selector present (navbar_langsel)? #{response.body.include?('language-selector')}"
    puts "navbar code span 'ES'? #{response.body.include?('>ES<')}"

    patch '/language', params: { language: 'en' }.to_json, headers: { 'Content-Type' => 'application/json' }
    puts "PATCH status=#{response.status} body=#{response.body[0, 80]} session_lang=#{session[:language_id].inspect}"

    get '/home/index'
    puts "GET2 status=#{response.status} I18n.locale=#{I18n.locale} session_lang=#{session[:language_id].inspect}"
    puts "navbar code span 'EN'? #{response.body.include?('>EN<')}"
  end
end
