# frozen_string_literal: true

module Admin
  module BranchFilters
    private

    def normalize_branch_filters(scope)
      @branch_filters = BranchesListing::FILTER_KEYS.index_with { |key| params[key].to_s.strip }
      @branch_filters['search'] = @branch_filters['search'].first(150)
      retain_branch_filter('status', %w[active inactive])
      retain_branch_filter('contact', %w[with_phone without_phone with_email without_email])
      retain_branch_filter('team', %w[assigned unassigned])
      normalize_branch_locations(scope)
      %w[created_from created_to].each do |key|
        @branch_filters[key] = valid_branch_date(@branch_filters[key])
      end
    end

    def normalize_branch_locations(scope)
      load_branch_countries(scope)
      retain_branch_filter('country_id', @branch_countries.map { |country| country.id.to_s })
      located = branch_location_scope(scope, 'country_id')
      @branch_filters['state'] = @branch_filters['state'].first(100)
      @branch_filters['city'] = @branch_filters['city'].first(100)
      @branch_states = branch_location_values(located, 'state')
      @branch_cities = branch_location_values(branch_location_scope(located, 'state'), 'city')
    end

    def load_branch_countries(scope)
      ids = scope.distinct.pluck('addresses.country_id').compact
      selected = @branch_filters['country_id']
      ids << selected if selected.match?(/\A\d+\z/)
      @branch_countries = (Country.active.ordered.to_a + Country.with_deleted.where(id: ids).to_a).uniq(&:id)
    end

    def branch_location_scope(scope, key)
      return scope if @branch_filters[key].blank?

      scope.where(addresses: { key => @branch_filters[key] })
    end

    def branch_location_values(scope, key)
      column = Address.arel_table[key]
      values = scope.where.not(addresses: { key => [nil, ''] }).distinct.order(column).pluck(column)
      values | [@branch_filters[key]].compact_blank
    end

    def retain_branch_filter(key, options)
      @branch_filters[key] = '' unless options.include?(@branch_filters[key])
    end

    def valid_branch_date(value)
      return '' unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      date = Date.iso8601(value)
      date.year.positive? ? date.iso8601 : ''
    rescue ArgumentError
      ''
    end

    def filter_branches(scope)
      scope = search_branches(scope) if @branch_filters['search'].present?
      scope = filter_branch_attributes(scope)
      filter_branch_dates(filter_branch_team(filter_branch_contacts(scope)))
    end

    def filter_branch_attributes(scope)
      scope = scope.where(status: @branch_filters['status'] == 'active') if @branch_filters['status'].present?
      %w[country_id state city].each { |key| scope = branch_location_scope(scope, key) }
      scope
    end

    def filter_branch_team(scope)
      assigned = Branch.team_assignments(current_organization).where.not(branch_id: nil).select(:branch_id)
      case @branch_filters['team']
      when 'assigned' then scope.where(id: assigned)
      when 'unassigned' then scope.where.not(id: assigned)
      else scope
      end
    end

    def filter_branch_contacts(scope)
      phones = Phone.active.where(phoneable_type: 'Branch', kind: 'mobile', primary: true).select(:phoneable_id)
      case @branch_filters['contact']
      when 'with_phone' then scope.where(id: phones)
      when 'without_phone' then scope.where.not(id: phones)
      when 'with_email' then scope.where.not(contact_email: [nil, ''])
      when 'without_email' then scope.where(contact_email: [nil, ''])
      else scope
      end
    end

    def filter_branch_dates(scope)
      from = @branch_filters['created_from']
      to = @branch_filters['created_to']
      if from.present? && to.present? && from > to
        @branch_filter_error = I18n.t('admin.branch_workspace.invalid_period')
        return scope.none
      end
      scope = scope.where(branches: { created_at: Time.zone.parse(from).beginning_of_day.. }) if from.present?
      scope = scope.where(branches: { created_at: ...Time.zone.parse(to).next_day.beginning_of_day }) if to.present?
      scope
    end

    def search_branches(scope)
      term = @branch_filters['search'].downcase.tr('áéíóúüñ', 'aeiouun')
      query = "%#{Branch.sanitize_sql_like(term)}%"
      text = "TRANSLATE(LOWER(CONCAT_WS(' ', branches.name, branches.code, branches.contact_email, " \
             'addresses.street, addresses.neighborhood, addresses.city, addresses.state, addresses.postal_code)), ' \
             "'áéíóúüñ', 'aeiouun')"
      matches = scope.where("#{text} LIKE ?", query)
      digits = term.gsub(/\D/, '')
      return matches if digits.length < 3 || !term.match?(/\A[+\d()\s.-]+\z/)

      phones = Phone.active.where(phoneable_type: 'Branch').where('number LIKE ?', "%#{digits}%").select(:phoneable_id)
      matches.or(scope.where(id: phones))
    end
  end
end
