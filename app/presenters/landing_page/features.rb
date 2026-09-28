module LandingPage
  module Features
    def self.all
      [
        Feature.new(icon: "bolt", title: "Ventas Veloces", description: "Cobra en caja en segundos. Compatible con lectores de código de barra, terminales bancarias y facturación electrónica instantánea.", color: :emerald),
        Feature.new(icon: "inventory", title: "Control de Inventarios", description: "Sincronización multi-sucursal en tiempo real. Recibe alertas automatizadas cuando tus productos estrella se estén agotando.", color: :teal),
        Feature.new(icon: "chart", title: "Reportes Analíticos", description: "Visualiza tus ganancias netas, horas pico de venta y rendimiento de tus cajeros desde cualquier dispositivo móvil o computadora.", color: :dark_emerald)
      ]
    end
  end
end
