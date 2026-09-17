module LandingPage
  module Features
    def self.all
      [
        Feature.new(
          icon: 'shopping-cart',
          title: 'Ventas rápidas',
          description: 'Cobra en segundos con lector de códigos de barras, múltiples formas de pago y ticket inmediato.',
          color: :blue
        ),
        Feature.new(
          icon: 'cube',
          title: 'Inventario en tiempo real',
          description: 'Controla existencias por sucursal, recibe alertas de stock mínimo y evita ventas sin producto.',
          color: :emerald
        ),
        Feature.new(
          icon: 'users',
          title: 'Clientes',
          description: 'Registra a tus clientes, consulta su historial de compras y aplica descuentos personalizados.',
          color: :purple
        ),
        Feature.new(
          icon: 'chart-bar',
          title: 'Reportes y Estadísticas',
          description: 'Conoce tus ventas, utilidades y productos más vendidos con reportes que se actualizan solos.',
          color: :amber
        ),
        Feature.new(
          icon: 'document-text',
          title: 'Facturación',
          description: 'Emite comprobantes desde la misma venta y mantén tu información fiscal siempre ordenada.',
          color: :red
        ),
        Feature.new(
          icon: 'device-phone-mobile',
          title: 'Acceso desde cualquier dispositivo',
          description: 'Trabaja en computadora, tablet o celular. Solo necesitas un navegador y conexión a internet.',
          color: :cyan
        )
      ]
    end
  end
end
