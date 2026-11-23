# frozen_string_literal: true

# Validate ownership before binding nested form inputs. Invalid targets must never
# be dereferenced by an error template, even when the parent fails validation.
class CommercialSubmittedReferences
  def initialize(organization, attributes)
    @organization = organization
    @rows = case attributes
            when ActionController::Parameters then attributes.to_h.values
            when Hash then attributes.values
            else Array.wrap(attributes)
            end
    raise ActiveRecord::NestedAttributes::TooManyRecords if @rows.size > 50
  end

  def validate!(targets)
    targets.each do |field, model|
      ids = submitted_ids(field)
      next if ids.empty?

      raise ActiveRecord::RecordNotFound unless ids.all? { |id| id.match?(/\A[1-9]\d{0,18}\z/) }

      owned = model.with_deleted.where(organization: @organization, id: ids).pluck(:id).map(&:to_s)
      raise ActiveRecord::RecordNotFound unless (ids - owned).empty?
    end
  end

  private

  def submitted_ids(field)
    @rows.filter_map { |row| row[field].presence&.to_s }.uniq
  end
end
