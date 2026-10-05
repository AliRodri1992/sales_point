# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LandingPage::Testimonials do
  describe '.all' do
    it 'resolves every testimonial translation for every supported locale' do
      expected_keys = %w[alejandro beatriz carlos diana eduardo sofia]

      %i[es en ko].each do |locale|
        I18n.with_locale(locale) do
          testimonials = described_class.all

          expect(testimonials.size).to eq(expected_keys.size)

          testimonials.each_with_index do |testimonial, index|
            expected_keys[index]

            expect(testimonial.name).not_to include('translation missing')
            expect(testimonial.company).not_to include('translation missing')
            expect(testimonial.position).not_to include('translation missing')
            expect(testimonial.quote).not_to include('translation missing')

            expect(testimonial.name).not_to include("\#{key}")
            expect(testimonial.quote).not_to include("\#{key}")
          end
        end
      end
    end
  end
end
