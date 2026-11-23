# frozen_string_literal: true

module CommercialLifecycle
  extend ActiveSupport::Concern

  ACTIVATION_FROM = { 'activate' => 'draft', 'resume' => 'paused' }.freeze

  included do
    enum :status, { draft: 'draft', active: 'active', paused: 'paused', archived: 'archived' },
         validate: true, default: :draft
    normalizes :code, with: ->(value) { value.strip.upcase }
    validates :code, length: { maximum: 50 }, uniqueness: { scope: :organization_id }, allow_blank: true
    validates :priority, numericality: { only_integer: true, in: -2_147_483_648..2_147_483_647 }
    validate :preserve_commercial_identity, on: :update
    before_create :allocate_commercial_code, if: -> { code.blank? }
  end

  def effective_status(at: Time.current)
    return status unless active?
    return 'expired' if ends_at && ends_at <= at
    return 'scheduled' if starts_at && starts_at > at
    return 'exhausted' if quota_exhausted?

    'active'
  end

  def transition_available?(action, at: Time.current)
    return false unless persisted?

    case action
    when 'activate', 'resume' then status == ACTIVATION_FROM.fetch(action) && eligible_for_activation?(at)
    when 'pause' then %w[scheduled active].include?(effective_status(at:))
    when 'archive' then !archived?
    else action == 'duplicate'
    end
  end

  private

  def eligible_for_activation?(time)
    (ends_at.nil? || ends_at > time) && !quota_exhausted? && activation_content?(time)
  end

  def quota_exhausted?
    false
  end

  def preserve_commercial_identity
    errors.add(:code, :invalid) if will_save_change_to_code?
    errors.add(:organization_id, :invalid) if will_save_change_to_organization_id?
  end

  # Allocate inside the insertion transaction. Form validation alone never reserves a number.
  def allocate_commercial_code
    Organization.lock.find(organization_id)
    prefix = self.class::CODE_PREFIX
    reserved = self.class.with_deleted.where(organization_id:).where('code ~ ?', "^#{prefix}-[0-9]+$")
    previous = reserved.maximum(Arel.sql("CAST(split_part(code, '-', 2) AS numeric)")).to_i
    self.code = "#{prefix}-#{format('%06d', previous + 1)}"
  end
end
