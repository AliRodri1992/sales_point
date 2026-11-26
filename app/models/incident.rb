# frozen_string_literal: true

class Incident < ApplicationRecord
  FREQUENCIES = %w[first intermittent always].freeze
  SCREENS = {
    'admin/dashboard' => %w[index], 'system_roles' => %w[index show new edit],
    'admin/products' => %w[index show new edit], 'admin/promotions' => %w[index show new edit],
    'admin/categories' => %w[index new edit], 'admin/price_lists' => %w[index show new edit],
    'admin/clients' => %w[index show new edit], 'admin/branches' => %w[index show new edit],
    'admin/suppliers' => %w[index show new edit], 'admin/inventory_overview' => %w[index],
    'admin/supplier_payments' => %w[index show new], 'admin/purchase_orders' => %w[index show new edit],
    'admin/users' => %w[index show new edit], 'admin/inventories' => %w[index show]
  }.freeze
  FORMATS = {
    'png' => %w[image/png], 'jpg' => %w[image/jpeg], 'jpeg' => %w[image/jpeg], 'webp' => %w[image/webp],
    'pdf' => %w[application/pdf], 'csv' => %w[text/csv text/plain], 'txt' => %w[text/plain],
    'mp4' => %w[video/mp4], 'xls' => %w[application/vnd.ms-excel],
    'xlsx' => %w[application/vnd.openxmlformats-officedocument.spreadsheetml.sheet],
    'doc' => %w[application/msword],
    'docx' => %w[application/vnd.openxmlformats-officedocument.wordprocessingml.document]
  }.freeze

  belongs_to :organization
  belongs_to :reporter, class_name: 'User'
  belongs_to :branch, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true
  belongs_to :duplicate_of, class_name: 'Incident', optional: true
  has_many :incident_events, dependent: :destroy
  has_many_attached :attachments
  validates :description, presence: true, length: { maximum: 8000 }
  validates :expected_result, length: { maximum: 4000 }
  validates :operation_reference, length: { maximum: 160 }
  normalizes :category, with: ->(value) { value.presence }
  validates :category, inclusion: { in: ->(_) { IncidentType.available.pluck(:code) } }, allow_blank: true, on: :create
  validates :frequency, inclusion: { in: FREQUENCIES }, allow_blank: true
  validates :affected_module, inclusion: { in: SCREENS.keys }, allow_blank: true
  validates :status, inclusion: { in: %w[reported reviewing resolved] }
  validates :priority, inclusion: { in: %w[low normal high] }, allow_blank: true
  validates :resolution, presence: true, if: -> { status == 'resolved' }
  validate :check_screen
  validate :check_files
  before_create :allocate_folio

  def record_followup!(actor, attributes)
    with_lock do
      assign_attributes(attributes)
      self.assignee = actor
      self.resolved_by = actor if status_changed? && status == 'resolved'
      self.resolved_at = Time.current if status_changed? && status == 'resolved'
      self.resolved_by = self.resolved_at = nil unless status == 'resolved'
      save!
      incident_events.create!(actor: actor, kind: status, body: resolution)
    end
  end

  def to_param
    folio
  end

  private

  def check_screen
    if affected_screen.present? && SCREENS.fetch(affected_module, []).exclude?(affected_screen)
      errors.add(:affected_screen, :invalid)
    end
  end

  def check_files
    attachments.each do |file|
      extension = file.filename.extension.to_s.downcase
      errors.add(:attachments, :invalid) unless FORMATS.fetch(extension, []).include?(file.content_type)
    end
  end

  def allocate_folio
    timestamp = Time.current.in_time_zone(Rails.application.config.time_zone)
    day = self.class.connection.quote(timestamp.to_date)
    sequence = self.class.connection.select_value(<<~SQL.squish)
      INSERT INTO incident_daily_counters (day, sequence) VALUES (#{day}, 1)
      ON CONFLICT (day) DO UPDATE SET sequence = incident_daily_counters.sequence + 1
      WHERE incident_daily_counters.sequence < 999999 RETURNING sequence
    SQL
    unless sequence
      errors.add(:folio, :invalid)
      throw :abort
    end
    self.folio = format('Inc%<minute>s%<count>06d', minute: timestamp.strftime('%Y%m%d%H%M'), count: sequence)
  end
end
