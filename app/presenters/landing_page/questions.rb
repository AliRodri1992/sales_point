module LandingPage
  module Questions
    def self.all
      [
        Question.new(question: "¿Es compatible con mi hardware actual?", answer: "Sí. Delta POS funciona en cualquier navegador moderno mediante tablets, computadoras y smartphones. Es compatible con el 95% de las impresoras térmicas y lectores USB/Bluetooth del mercado."),
        Question.new(question: "¿El sistema funciona si me quedo sin internet?", answer: "Nuestra arquitectura híbrida te permite seguir cobrando de forma local. En cuanto la conexión regrese, los datos y ventas se sincronizan automáticamente con la nube corporativa.")
      ]
    end
  end
end