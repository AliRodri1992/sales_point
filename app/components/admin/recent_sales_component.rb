# frozen_string_literal: true

module Admin
  class RecentSalesComponent < ViewComponent::Base
    Sale = Data.define(
      :folio,
      :customer,
      :payment_method,
      :total,
      :status,
      :status_background,
      :status_text
    )

    SALES = [
      Sale.new(
        folio: '#NV-0186',
        customer: 'Juan Perez',
        payment_method: 'Tarjeta',
        total: '$1,250.00',
        status: 'Completada',
        status_background: 'bg-emerald-50',
        status_text: 'text-emerald-700'
      ),
      Sale.new(
        folio: '#NV-0185',
        customer: 'María Lopez',
        payment_method: 'Efectivo',
        total: '$840.00',
        status: 'Completada',
        status_background: 'bg-emerald-50',
        status_text: 'text-emerald-700'
      ),
      Sale.new(
        folio: '#NV-0184',
        customer: 'Publico general',
        payment_method: 'Efectivo',
        total: '$420.00',
        status: 'Completada',
        status_background: 'bg-emerald-50',
        status_text: 'text-emerald-700'
      ),
      Sale.new(
        folio: '#NV-0183',
        customer: 'Carlos Hernandez',
        payment_method: 'Transferencia',
        total: '$2,150.00',
        status: 'Pendiente',
        status_background: 'bg-amber-50',
        status_text: 'text-amber-700'
      )
    ].freeze

    private

    def sales
      SALES
    end
  end
end
