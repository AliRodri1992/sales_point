# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::UsersController, type: :controller do
  def request_params(values)
    allow(controller).to receive(:params).and_return(ActionController::Parameters.new(values))
  end

  describe 'server-side user page sizing' do
    it 'uses the default when the result set fits one page' do
      request_params(per_page: '5')
      expect(controller.send(:per_page_param, 9)).to eq(10)
    end

    it 'uses the explicitly allowed page size for long lists' do
      request_params(per_page: '5')
      expect(controller.send(:per_page_param, 17)).to eq(5)
    end

    it 'accepts the maximum explicitly allowed page size' do
      request_params(per_page: '15')
      expect(controller.send(:per_page_param, 30)).to eq(15)
    end

    it 'rejects oversized and malformed page limits' do
      %w[999 invalid -5].each do |value|
        request_params(per_page: value)
        expect(controller.send(:per_page_param, 30)).to eq(10)
      end
    end
  end

  describe 'safe ordering' do
    it 'allows sorting user names in descending order' do
      request_params(sort: 'users.username', direction: 'desc')
      expect(controller.send(:apply_sorting, User.all).to_sql).to include('"users"."username" DESC')
    end

    it 'uses the email column for a disallowed sort key' do
      request_params(sort: 'users.encrypted_password', direction: 'asc')
      expect(controller.send(:apply_sorting, User.all).to_sql).to include('"users"."email" ASC')
    end

    it 'ignores injected SQL sort directions' do
      request_params(sort: 'users.email', direction: 'DESC; DELETE')
      expect(controller.send(:apply_sorting, User.all).to_sql).to include('"users"."email" ASC')
    end
  end
end
