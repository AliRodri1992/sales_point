# frozen_string_literal: true

module DemoRequests
  class Filters
    PER_PAGE_OPTIONS = [5, 10, 15].freeze

    def initialize(params, current_user)
      @params = params
      @current_user = current_user
    end

    def call
      scope = policy_scope.includes(:assigned_to)
      apply_filters(scope)
    end

    def metrics
      scope = policy_scope
      counts = scope.group(:status).count

      {
        total: scope.count,
        pending: counts.fetch('pending', 0),
        contacted: counts.fetch('contacted', 0),
        scheduled: counts.fetch('scheduled', 0),
        completed: counts.fetch('completed', 0),
        converted: counts.fetch('converted', 0),
        overdue_follow_ups: overdue_follow_ups_count(scope),
        conversion_rate: conversion_rate(scope, counts)
      }
    end

    def pagination_info
      scope = policy_scope
      total_count = scope.count
      per_page = per_page_param
      total_pages = [(total_count / per_page.to_f).ceil, 1].max
      current_page = @params[:page].to_i.clamp(1, total_pages)

      {
        scope: scope,
        total_count:,
        per_page:,
        total_pages:,
        current_page:
      }
    end

    private

    def policy_scope
      DemoRequest
    end

    def apply_filters(scope)
      scope = scope.where(status: @params[:status]) if valid_status?
      scope = apply_follow_up_filters(scope)
      scope = apply_outcome_filters(scope)
      scope = apply_search_filter(scope)
      apply_pagination(scope)
    end

    def valid_status?
      DemoRequest.statuses.key?(@params[:status])
    end

    def apply_follow_up_filters(scope)
      return scope if @params[:follow_up].blank?

      scope = scope.where.not(next_follow_up_at: nil)
                   .where.not(status: %w[converted cancelled])

      apply_follow_up_time_filters(scope)
    end

    def apply_follow_up_time_filters(scope)
      case @params[:follow_up]
      when 'overdue'
        scope.where(next_follow_up_at: ..Time.current)
      when 'upcoming'
        scope.where('next_follow_up_at > ?', Time.current)
      else
        scope
      end
    end

    def apply_outcome_filters(scope)
      return scope if @params[:contact_outcome].blank?
      return scope unless DemoRequest::CONTACT_OUTCOMES.include?(@params[:contact_outcome])

      scope.where(contact_outcome: @params[:contact_outcome])
    end

    def apply_demo_outcome_filters(scope)
      return scope if @params[:demo_outcome].blank?
      return scope unless DemoRequest::DEMO_OUTCOMES.include?(@params[:demo_outcome])

      scope.where(demo_outcome: @params[:demo_outcome])
    end

    def apply_search_filter(scope)
      return scope if @params[:search].blank?

      term = "%#{DemoRequest.sanitize_sql_like(@params[:search].strip)}%"
      scope.where(
        'name ILIKE :term OR email ILIKE :term OR company ILIKE :term OR phone ILIKE :term',
        term:
      )
    end

    def apply_pagination(scope)
      pagination = pagination_info

      scope = scope.where(contact_outcome: @params[:contact_outcome]) if @params[:contact_outcome].present?
      scope = scope.where(demo_outcome: @params[:demo_outcome]) if @params[:demo_outcome].present?
      scope = apply_ordering(scope)
      scope.limit(pagination[:per_page]).offset((pagination[:current_page] - 1) * pagination[:per_page])
    end

    def apply_ordering(scope)
      order_sql = 'CASE WHEN next_follow_up_at IS NOT NULL ' \
                  'AND next_follow_up_at <= NOW() THEN 0 ELSE 1 END, created_at DESC'
      scope.order(Arel.sql(order_sql))
    end

    def per_page_param
      value = @params[:per_page].to_i
      PER_PAGE_OPTIONS.include?(value) ? value : 10
    end

    def overdue_follow_ups_count(scope)
      scope.where.not(next_follow_up_at: nil)
           .where(next_follow_up_at: ..Time.current)
           .where.not(status: %w[converted cancelled]).count
    end

    def conversion_rate(scope, counts)
      scope.none? ? 0 : ((counts.fetch('converted', 0).to_f / scope.count) * 100).round(1)
    end
  end
end
