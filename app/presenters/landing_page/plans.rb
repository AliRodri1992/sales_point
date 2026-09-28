module LandingPage
  module Plans
    def self.all
      [
        Plan.new(name: "Delta Esencial", price: 29, description: "Ideal para comercios locales independientes.", features: ["1 Sucursal y 2 Cajas integradas", "Inventario estándar de productos"], featured: false),
        Plan.new(name: "Delta Pro Cloud", price: 59, description: "Para empresas en expansión y cadenas regionales.", features: ["Sucursales y Cajas **Ilimitadas**", "Inventario Automatizado Multi-sucursal", "Analíticas en tiempo real + API Acceso"], featured: true)
      ]
    end
  end
end
