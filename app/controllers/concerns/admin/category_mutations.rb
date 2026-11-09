# frozen_string_literal: true

module Admin
  # Category-only mutations. Keeps controller routing and read concerns small.
  module CategoryMutations
    def create
      @category = Category.new(category_params.merge(organization: current_organization))
      return category_invalid(:new) unless @category.save

      category_saved(:created)
    rescue ActiveRecord::RecordNotUnique
      category_duplicate(:new)
    end

    def update
      return category_invalid(:edit) unless @category.update(category_params)

      category_saved(:updated)
    rescue ActiveRecord::RecordNotUnique
      category_duplicate(:edit)
    end

    def destroy
      removed = @category.with_lock do
        next false if @category.in_use?

        @category.update!(deleted_at: Time.current)
        true
      end
      return category_in_use_response unless removed

      category_saved(:destroyed)
    end

    private

    def category_invalid(template)
      render template, status: :unprocessable_content
    end

    def category_duplicate(template)
      @category.errors.add(:code, :taken)
      category_invalid(template)
    end

    def category_saved(action)
      load_categories
      notify_category(current_user, @category, action.to_s)
      return if redirect_without_catalog_listing(@category, action)

      broadcast_categories_update
      respond_to do |format|
        format.turbo_stream { @swal_message = t("admin.categories.#{action}") }
        format.html do
          redirect_to admin_categories_path(request.query_parameters),
                      notice: t("admin.categories.#{action}")
        end
      end
    end
  end
end
