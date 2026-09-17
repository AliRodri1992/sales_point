module LandingPage
  module Questions
    def self.all
      [
        Question.new(
          question: '¿Necesito instalar algo en mi computadora?',
          answer: 'No. PuntoVeloz funciona desde el navegador, así que puedes usarlo en cualquier equipo con internet.'
        ),
        Question.new(
          question: '¿Puedo seguir vendiendo si se cae el internet?',
          answer: 'Sí. El punto de venta guarda las operaciones localmente y las sincroniza cuando vuelve la conexión.'
        ),
        Question.new(
          question: '¿Puedo migrar mi catálogo de productos?',
          answer: 'Puedes importar tus productos desde un archivo de Excel o CSV y te acompañamos en la primera carga.'
        ),
        Question.new(
          question: '¿Hay permanencia mínima?',
          answer: 'No hay contratos forzosos. El plan es mensual y puedes cambiarlo o cancelarlo cuando lo necesites.'
        ),
        Question.new(
          question: '¿Qué incluye la prueba gratuita?',
          answer: 'Todas las funciones del plan Profesional durante 14 días, sin registrar una tarjeta de crédito.'
        )
      ]
    end
  end
end
