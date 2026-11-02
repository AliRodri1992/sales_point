# frozen_string_literal: true

require_relative 'demo_purchasing_examples'

# Small, deterministic tenant-bound examples for models missing from db:seed.
module DemoOperationalExamples
  INVENTORY_BRANCH_COUNT = 3

  module_function

  def seed_employees!(organization:)
    emails = ['administrador@delta.com'] + (1..30).map { |number| "user#{number}@delta.com" }
    User.where(email: emails).find_each do |user|
      employee = organization.employees.where(deleted_at: nil).find_or_initialize_by(email: user.email)
      if employee.new_record?
        employee.assign_attributes(first_name: user.email == emails.first ? 'Administrador' : 'Usuario',
                                   last_name: user.username.presence || 'Delta', status: :active)
        employee.save!
      end
      user.update!(employee:) unless user.employee_id
    end
  end

  def seed_organization_contacts!(organization:)
    4.times do |index|
      number = index + 1
      email = "contacto-delta-#{number}@example.com"
      next if organization.contacts.exists?(email:)

      organization.contacts.create!(
        name: "Contacto Delta #{number}",
        email:, position: %w[Administracion Ventas Compras Soporte].fetch(index),
        primary: index.zero? && !organization.contacts.available.exists?(primary: true),
        active: true, notes: 'Contacto de demostración.'
      )
    end
  end

  def seed_payment_integrations!(organization:)
    %w[card qr].each do |provider|
      next if organization.payment_integrations.exists?(provider:, deleted_at: nil)

      organization.payment_integrations.create!(provider:, status: :pending, configuration: {})
    end
  end

  def seed_inventories!(organization:, admin:)
    branches = organization.branches.not_deleted.order(:id).limit(INVENTORY_BRANCH_COUNT).to_a
    organization.products.not_deleted.order(:id).find_each.with_index do |product, index|
      branches.each_with_index do |branch, branch_index|
        seed_inventory!(organization:, admin:, product:, branch:, quantity: 12 + ((index + branch_index) % 25))
      end
    end
  end

  def seed_inventory!(organization:, admin:, branch:, product:, quantity:)
    inventory = Inventory.find_or_create_by!(organization:, branch:, product:) do |record|
      record.assign_attributes(stock: quantity, min_stock: 5, max_stock: 300)
    end
    return unless inventory.previously_new_record?

    inventory.inventory_movements.create!(
      organization:, user: admin, kind: 'adjustment', quantity: inventory.stock,
      stock_before: 0, stock_after: inventory.stock,
      reference: "DEMO-INIT-#{branch.id}-#{product.id}"
    )
  end
end
