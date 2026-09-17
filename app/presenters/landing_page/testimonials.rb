module LandingPage
  module Testimonials
    def self.all
      [
        Testimonial.new(
          name: 'Laura Méndez',
          company: 'Abarrotes La Esquina',
          position: 'Propietaria',
          quote: 'Antes cerraba caja con papel y calculadora. Hoy sé cuánto vendí y qué me falta surtir en un minuto.',
          avatar: 'landing/avatar.svg'
        ),
        Testimonial.new(
          name: 'Carlos Ibáñez',
          company: 'Ferretería Norte',
          position: 'Gerente de operaciones',
          quote: 'Tenemos tres sucursales y por fin vemos el inventario de todas en la misma pantalla.',
          avatar: 'landing/avatar.svg'
        ),
        Testimonial.new(
          name: 'Andrea Solís',
          company: 'Boutique Aurora',
          position: 'Fundadora',
          quote: 'La capacitación del personal tomó una tarde. La interfaz es tan simple que casi no hubo preguntas.',
          avatar: 'landing/avatar.svg'
        )
      ]
    end
  end
end
