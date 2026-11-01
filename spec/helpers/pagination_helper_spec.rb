# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaginationHelper, type: :helper do
  before do
    allow(helper).to receive(:t) do |key|
      { 'admin.pagination.prev' => 'Previous', 'admin.pagination.next' => 'Next' }.fetch(key)
    end
  end

  describe '#pagination_links' do
    it 'returns an empty string when there is only one page' do
      expect(helper.pagination_links(1)).to eq('')
    end

    it 'omits the previous link on the first page and includes the next link' do
      allow(helper).to receive(:params).and_return(ActionController::Parameters.new(page: 1))
      allow(helper).to receive(:page_links).with(1, 3, frame: nil).and_return(['pages'])
      allow(helper).to receive(:next_link).with(1, 3, frame: nil).and_return('next')

      expect(helper).not_to receive(:prev_link)
      expect(helper.pagination_links(3)).to include('pages', 'next')
    end

    it 'omits the next link on the last page and includes the previous link' do
      allow(helper).to receive(:params).and_return(ActionController::Parameters.new(page: 3))
      allow(helper).to receive(:page_links).with(3, 3, frame: nil).and_return(['pages'])
      allow(helper).to receive(:prev_link).with(3, frame: nil).and_return('previous')

      expect(helper).not_to receive(:next_link)
      expect(helper.pagination_links(3)).to include('pages', 'previous')
    end
  end

  describe '#prev_link and #next_link' do
    it 'disables the previous link on the first page' do
      expect(helper.prev_link(1)).to include('aria-disabled="true"')
    end

    it 'disables the next link on the last page' do
      expect(helper.next_link(3, 3)).to include('aria-disabled="true"')
    end
  end

  describe '#page_links' do
    it 'renders the current page as an active span and other pages as links' do
      allow(helper).to receive(:pagination_link).and_return('page-link')

      links = helper.page_links(2, 3)

      expect(links.first).to eq('page-link')
      expect(links.second).to include('aria-current="page"')
      expect(links.third).to eq('page-link')
    end
  end

  describe '#pagination_link' do
    it 'renders enabled links without a Turbo Frame when none is requested' do
      allow(helper).to receive(:url_for).and_return('/admin/products?page=2')
      allow(helper).to receive(:request).and_return(instance_double(ActionDispatch::Request, query_parameters: {}))

      result = helper.pagination_link('2', 2, false)

      expect(result).to include('href="/admin/products?page=2"')
      expect(result).not_to include('data-turbo-frame')
    end

    it 'renders enabled links with a Turbo Frame when requested' do
      allow(helper).to receive(:url_for).and_return('/admin/products?page=2')
      allow(helper).to receive(:request).and_return(instance_double(ActionDispatch::Request, query_parameters: {}))

      result = helper.pagination_link('2', 2, false, frame: 'products_list')

      expect(result).to include('href="/admin/products?page=2"')
      expect(result).to include('data-turbo-frame="products_list"')
    end
  end
end
