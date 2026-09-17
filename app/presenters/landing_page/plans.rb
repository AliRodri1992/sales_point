module LandingPage
  module Plans
    def self.all
      [
        Plan.new(
          name: 'Inicial',
          price: 19,
          description: 'Para negocios que empiezan a ordenar sus ventas.',
          featured: false,
          features: [
            '1 sucursal y 2 usuarios',
            'Ventas e inventario',
            'Reportes básicos',
            'Soporte por correo'
          ]
        ),
        Plan.new(
          name: 'Profesional',
          price: 39,
          description: 'El plan que elige la mayoría de nuestros clientes.',
          featured: true,
          features: [
            '3 sucursales y 10 usuarios',
            'Compras y proveedores',
            'Caja, turnos y devoluciones',
            'Reportes avanzados',
            'Soporte prioritario'
          ]
        ),
        Plan.new(
          name: 'Empresarial',
          price: 79,
          description: 'Para cadenas que necesitan control total.',
          featured: false,
          features: [
            'Sucursales y usuarios ilimitados',
            'Roles y permisos a detalle',
            'Exportación contable',
            'Acompañamiento en la implementación',
            'Soporte 24/7'
          ]
        )
      ]
    end
  end
end
