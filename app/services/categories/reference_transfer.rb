# frozen_string_literal: true

module Categories
  # Transfer current references together; retired records retain their historical links.
  class ReferenceTransfer
    include ActiveModel::Model

    attr_accessor :target_category_id
    attr_reader :source, :target

    validates :target_category_id, presence: true, format: { with: /\A[1-9]\d*\z/, allow_blank: true }

    def initialize(source:, target_category_id: nil)
      @source = source
      super(target_category_id:)
    end

    def save
      return false unless valid?

      Category.transaction do
        lock_categories
        raise ActiveRecord::Rollback if errors.any?

        transfer(source.products)
        transfer(source.promotion_conditions)
      end
      errors.empty?
    rescue ActiveRecord::RecordInvalid
      errors.add(:base, I18n.t('admin.categories.references.failed'))
      false
    end

    private

    def lock_categories
      categories = locked_categories
      @target = categories[target_category_id.to_i]
      return if categories.key?(source.id) && target&.active? && target.id != source.id

      errors.add(:target_category_id, :invalid)
    end

    def locked_categories
      # Serialize status/removal changes without blocking the FK KEY SHARE lock
      # of a product editor that already holds its product row.
      Category.where(organization_id: source.organization_id, id: [source.id, target_category_id])
              .order(:id).lock('FOR NO KEY UPDATE').index_by(&:id)
    end

    def transfer(scope)
      scope.lock.find_each do |record|
        if record.organization_id != source.organization_id
          record.errors.add(:category, :invalid)
          raise ActiveRecord::RecordInvalid, record
        end
        record.update!(category: target)
      end
    end
  end
end
