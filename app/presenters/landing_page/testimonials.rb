module LandingPage
  module Testimonials
    def self.all
      [
        testimonial("Alejandro Gómez", "Minimarket El Triunfo", "Redujo nuestras filas un 40%. La interfaz es tan intuitiva que el entrenamiento de nuevos cajeros toma menos de diez minutos."),
        testimonial("Beatriz Mendoza", "Boutique Bloom", "La sincronización de stock en la nube es real. Ahora sé exactamente qué producto se vende más a cada hora sin esperar auditorías manuales."),
        testimonial("Carlos Ramírez", "Ferretería El Candado", "La facturación electrónica integrada nos ahorró horas de trabajo administrativo. El sistema cumple con todo lo legal al instante."),
        testimonial("Diana Silva", "Cafetería Urban Central", "La velocidad de procesamiento de tarjetas aumentó nuestras ventas en horas pico. Un cambio radical para el negocio."),
        testimonial("Eduardo Marín", "Tiendas Minimix (5 sucursales)", "La gestión multi-sucursal nos permitió controlar las tiendas de tres ciudades desde un solo panel. Indispensable para crecer."),
        testimonial("Sofia Palacios", "Boutique Glamour", "Las alertas de inventario bajo evitaron pérdidas de stock crítico. El soporte técnico responde en minutos ante dudas.")
      ]
    end

    def self.testimonial(name, company, quote)
      Testimonial.new(name: name, company: company, position: nil, quote: quote, avatar: nil)
    end
  end
end