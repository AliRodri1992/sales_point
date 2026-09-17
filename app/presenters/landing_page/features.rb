module LandingPage
  module Features
    def self.all
      [
        Feature.new(
          icon: 'shopping-cart',
          title: 'Ventas rápidas',
          description: 'Cobra en segundos con lector de códigos de barras, múltiples formas de pago y ticket inmediato.'
        ),
        Feature.new(
          icon: 'cube',
          title: 'Inventario en tiempo real',
          description: 'Controla existencias por sucursal, recibe alertas de stock mínimo y evita ventas sin producto.'
        ),
        Feature.new(
          icon: 'users',
          title: 'Clientes y fidelización',
          description: 'Registra a tus clientes, consulta su historial de compras y aplica descuentos personalizados.'
        ),
        Feature.new(
          icon: 'chart-bar',
          title: 'Reportes claros',
          description: 'Conoce tus ventas, utilidades y productos más vendidos con reportes que se actualizan solos.'
        ),
        Feature.new(
          icon: 'document-text',
          title: 'Facturación',
          description: 'Emite comprobantes desde la misma venta y mantén tu información fiscal siempre ordenada.'
        ),
        Feature.new(
          icon: 'device-phone-mobile',
          title: 'Desde cualquier dispositivo',
          description: 'Trabaja en computadora, tablet o celular. Solo necesitas un navegador y conexión a internet.'
        )
      ]
    end
  end
end
