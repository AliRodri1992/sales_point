module BreadcrumbsHelper
  BREADCRUMB_HANDLERS = {
    'admin/products' => :product_breadcrumb_items,
    'admin/dashboard' => :dashboard_breadcrumb_items,
    'admin/languages' => :language_breadcrumb_items,
    'admin/categories' => :category_breadcrumb_items,
    'system_roles' => :system_role_breadcrumb_items,
    'admin/branches' => :branch_breadcrumb_items,
    'admin/clients' => :client_breadcrumb_items,
    'admin/organizations' => :organization_breadcrumb_items,
    'admin/membership_plans' => :membership_plan_breadcrumb_items,
    'admin/subscriptions' => :subscription_breadcrumb_items
  }.freeze

  def breadcrumb_items
    [home_breadcrumb, *controller_breadcrumb_items]
  end

  private

  def home_breadcrumb
    { label: t('admin.breadcrumbs.home'), path: admin_dashboard_path }
  end

  def controller_breadcrumb_items
    send(BREADCRUMB_HANDLERS.fetch(params[:controller], :default_breadcrumb_items))
  end

  def default_breadcrumb_items
    [{ label: params[:controller].to_s.remove('admin/').humanize }]
  end

  def current_product
    controller.view_assigns['product']
  end

  def current_branch
    controller.view_assigns['branch']
  end

  def current_client
    controller.view_assigns['client']
  end

  def current_organization
    controller.view_assigns['organization']
  end

  def current_membership_plan
    controller.view_assigns['membership_plan']
  end

  def current_subscription
    controller.view_assigns['subscription']
  end

  def product_breadcrumb_items
    products_path = { label: t('admin.breadcrumbs.products'), path: admin_products_path }

    case params[:action]
    when 'new'
      [products_path, { label: t('admin.products.new.title') }]
    when 'edit', 'show', 'create', 'update', 'destroy'
      product_name = current_product&.name || t('admin.products.edit.label')
      [products_path, { label: product_name }]
    else
      [products_path]
    end
  end

  def dashboard_breadcrumb_items
    [{ label: t('admin.breadcrumbs.dashboard') }]
  end

  def language_breadcrumb_items
    [{ label: t('admin.breadcrumbs.languages') }]
  end

  def category_breadcrumb_items
    [{ label: t('admin.breadcrumbs.categories') }]
  end

  def branch_breadcrumb_items
    branches_path = { label: t('admin.breadcrumbs.branches'), path: admin_branches_path }

    case params[:action]
    when 'new'
      [branches_path, { label: t('admin.branches.form.new_title') }]
    when 'show'
      [branches_path, record_breadcrumb(current_branch, t('admin.branches.form.edit_title'))]
    when 'edit'
      branch = current_branch
      [branches_path,
       editable_record_breadcrumb(branch, t('admin.branches.form.edit_title'), method(:admin_branch_path)),
       { label: t('admin.branches.form.edit_title') }]
    else
      [branches_path]
    end
  end

  def client_breadcrumb_items
    clients_path = { label: t('admin.breadcrumbs.clients'), path: admin_clients_path }

    case params[:action]
    when 'new'
      [clients_path, { label: t('admin.clients.new.title') }]
    when 'show'
      [clients_path, record_breadcrumb(current_client, t('admin.clients.show.title'))]
    when 'edit'
      client = current_client
      client_name = client&.name || t('admin.clients.edit.title', name: '')
      [clients_path,
       editable_record_breadcrumb(client, client_name, method(:admin_client_path)),
       { label: t('admin.clients.edit.title', name: client_name) }]
    else
      [clients_path]
    end
  end


  def organization_breadcrumb_items
    organizations_path = { label: t('admin.breadcrumbs.organizations'), path: admin_organizations_path }

    case params[:action]
    when 'new'
      [organizations_path, { label: t('admin.organizations.new.title') }]
    when 'show'
      [organizations_path, record_breadcrumb(current_organization, t('admin.organizations.show.title'))]
    when 'edit'
      organization = current_organization
      name = organization&.name || t('admin.organizations.edit.title')
      [organizations_path, editable_record_breadcrumb(organization, name, method(:admin_organization_path)),
       { label: t('admin.organizations.edit.title') }]
    else
      [organizations_path]
    end
  end

  def membership_plan_breadcrumb_items
    plans_path = { label: t('admin.breadcrumbs.membership_plans'), path: admin_membership_plans_path }

    case params[:action]
    when 'new'
      [plans_path, { label: t('admin.membership_plans.new.title') }]
    when 'show'
      [plans_path, record_breadcrumb(current_membership_plan, t('admin.membership_plans.show.title'))]
    when 'edit'
      plan = current_membership_plan
      [plans_path, editable_record_breadcrumb(plan, plan&.name || t('admin.membership_plans.edit.title'), method(:admin_membership_plan_path)),
       { label: t('admin.membership_plans.edit.title') }]
    else
      [plans_path]
    end
  end

  def subscription_breadcrumb_items
    subscriptions_path = { label: t('admin.breadcrumbs.subscriptions'), path: admin_subscriptions_path }

    case params[:action]
    when 'new'
      [subscriptions_path, { label: t('admin.subscriptions.new.title') }]
    when 'show'
      [subscriptions_path, record_breadcrumb(current_subscription, t('admin.subscriptions.show.title'))]
    when 'edit'
      [subscriptions_path, editable_record_breadcrumb(current_subscription, t('admin.subscriptions.edit.title'), method(:admin_subscription_path)),
       { label: t('admin.subscriptions.edit.title') }]
    else
      [subscriptions_path]
    end
  end

  def record_breadcrumb(record, fallback)
    { label: record&.name || fallback }
  end

  def editable_record_breadcrumb(record, fallback, path_builder)
    record_breadcrumb(record, fallback).merge(path: record&.then { |value| path_builder.call(value) })
  end

  def system_role_breadcrumb_items
    roles_path = { label: t('admin.breadcrumbs.roles'), path: system_roles_path }

    case params[:action]
    when 'new', 'create'
      [roles_path, { label: t('admin.system_roles.new.title') }]
    when 'edit'
      [roles_path, { label: t('admin.system_roles.edit.title') }]
    else
      [roles_path]
    end
  end
end
