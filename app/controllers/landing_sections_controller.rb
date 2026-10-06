# frozen_string_literal: true

class LandingSectionsController < ApplicationController
  layout 'dashboard'

  before_action :authenticate_user!
  before_action :set_landing_section, only: %i[toggle update]
  before_action :authorize_landing_sections

  def index
    @landing_sections = LandingSection.ordered
  end

  def toggle
    @landing_section.update!(enabled: !@landing_section.enabled)

    redirect_to landing_sections_path,
                notice: t('dashboard.landing.updated')
  end

  def update
    if @landing_section.update(landing_section_params)
      redirect_to landing_sections_path,
                  notice: t('dashboard.landing.updated')
    else
      redirect_to landing_sections_path,
                  alert: @landing_section.errors.full_messages.to_sentence
    end
  end

  def reorder
    ids = Array(params[:ids]).map(&:to_i).uniq
    sections = LandingSection.where(id: ids)

    return redirect_to landing_sections_path, alert: t('dashboard.landing.reorder_error') unless sections.size == ids.size

    LandingSection.transaction do
      ids.each_with_index do |id, index|
        LandingSection.where(id:).update_all(position: -(index + 1), updated_at: Time.current)
      end

      ids.each_with_index do |id, index|
        LandingSection.where(id:).update_all(position: index + 1, updated_at: Time.current)
      end
    end

    redirect_to landing_sections_path, notice: t('dashboard.landing.reordered')
  end

  private

  def set_landing_section
    @landing_section = LandingSection.find(params[:id])
  end

  def landing_section_params
    params.expect(landing_section: %i[enabled])
  end

  def authorize_landing_sections
    if %w[toggle update].include?(action_name)
      authorize(@landing_section)
    elsif action_name == 'reorder'
      authorize(LandingSection, :reorder?)
    else
      authorize(LandingSection)
    end
  end
end
