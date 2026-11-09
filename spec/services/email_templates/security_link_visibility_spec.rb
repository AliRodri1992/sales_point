# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailTemplates::SecurityLinkVisibility do
  def visible_link?(html)
    fragment = Nokogiri::HTML.fragment(html)
    described_class.visible?(fragment.at_css('a[href]'))
  end

  it 'rejects links whose only text belongs to hidden children' do
    [
      '<span style="display:none">Hidden</span>',
      '<span style="visibility:hidden">Hidden</span>',
      '<span style="font-size:0px">Hidden</span>',
      '<span style="opacity:0">Hidden</span>',
      '<span hidden>Hidden</span>',
      '<span aria-hidden="true">Hidden</span>',
      '<span style="display: none !important">Hidden</span>',
      '<img alt="Reset" style="display:none" src="https://delta.test/icon.png">',
      '<img alt="Reset" width="0" src="https://delta.test/icon.png">',
      '<img alt="Reset" height="0" src="https://delta.test/icon.png">'
    ].each do |content|
      expect(visible_link?(%(<a href="https://delta.test/reset">#{content}</a>))).to be(false)
    end
  end

  it 'accepts a visible descendant even when other children are hidden' do
    markup = '<a href="https://delta.test/reset"><span style="display:none">Hidden</span><strong>Reset</strong></a>'
    expect(visible_link?(markup)).to be(true)
    expect(visible_link?('<a href="https://delta.test/reset"><img alt="Reset" src="https://delta.test/icon.png"></a>'))
      .to be(true)
  end

  it 'rejects links hidden by their own style or by an ancestor' do
    markup = '<div style="visibility:hidden"><a href="https://delta.test/reset">Reset</a></div>'
    expect(visible_link?(markup)).to be(false)
    expect(visible_link?('<a style="opacity:0" href="https://delta.test/reset">Reset</a>')).to be(false)
  end
end
