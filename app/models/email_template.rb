# frozen_string_literal: true

class EmailTemplate < ApplicationRecord
  validates :key, :locale, :subject, :html_body, :text_body, presence: true
  validates :key, uniqueness: { scope: :locale }
  validates :version, numericality: { only_integer: true, greater_than: 0 }

  def render_with(values)
    [subject, html_body, text_body].each_with_index.map do |source, index|
      source.gsub(/\{\{([a-z_]+)\}\}/) do |match|
        value = values.fetch(Regexp.last_match(1).to_sym) { match }.to_s
        index == 1 ? ERB::Util.html_escape(value) : value
      end
    end
  end
end
