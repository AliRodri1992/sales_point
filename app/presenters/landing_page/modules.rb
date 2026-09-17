module LandingPage
  module Modules
    def self.all
      [
        Feature.new(
          icon: 'building-storefront',
          title: 'Multisucursal',
          description: 'Administra varias sucursales desde una sola cuenta y compara su desempeño en un mismo panel.'
        ),
        Feature.new(
          icon: 'truck',
          title: 'Compras y proveedores',
          description: 'Registra órdenes de compra, controla costos y mantén al día la información de tus proveedores.'
        ),
        Feature.new(
          icon: 'banknotes',
          title: 'Caja y turnos',
          description: 'Abre y cierra caja por turno, registra retiros y detecta diferencias al final del día.'
        ),
        Feature.new(
          icon: 'user-group',
          title: 'Usuarios y permisos',
          description: 'Define roles para cajeros, supervisores y administradores con los permisos que cada uno necesita.'
        ),
        Feature.new(
          icon: 'arrow-path',
          title: 'Devoluciones',
          description: 'Procesa devoluciones y cancelaciones dejando siempre el inventario y la caja cuadrados.'
        ),
        Feature.new(
          icon: 'calculator',
          title: 'Cierres contables',
          description: 'Exporta tus movimientos en el formato que tu contador necesita, sin capturas manuales.'
        )
      ]
    end
  end
end
