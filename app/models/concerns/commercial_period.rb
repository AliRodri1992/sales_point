# frozen_string_literal: true

module CommercialPeriod
  extend ActiveSupport::Concern

  included do
    validate :valid_commercial_period
    scope :effective_at, lambda { |time|
      where('starts_at IS NULL OR starts_at <= ?', time).where('ends_at IS NULL OR ends_at > ?', time)
    }
  end

  private

  def valid_commercial_period
    %i[starts_at ends_at].each do |attribute|
      if public_send("#{attribute}_before_type_cast").present? && public_send(attribute).nil?
        errors.add(attribute, :invalid)
      end
    end
    errors.add(:ends_at, :invalid) if starts_at && ends_at && ends_at <= starts_at
  end
end
