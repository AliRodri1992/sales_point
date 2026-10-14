import { Controller } from "@hotwired/stimulus"

// Review parsed invoice fields before saving. The final create/update reparses XML server-side.
export default class extends Controller {
  static targets = ["file", "supplier", "result"]
  static values = { url: String }

  async load() {
    const file = this.fileTarget.files[0]
    if (!file) return

    const supplierId = this.supplierTarget.value
    if (!supplierId) {
      this.message("Selecciona un proveedor antes de cargar el XML.", true)
      return
    }

    const body = new FormData()
    body.append("xml_document", file)
    body.append("supplier_id", supplierId)
    this.message("Analizando CFDI...")

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || "El CFDI no se pudo analizar.")

      for (const [key, value] of Object.entries(data.fields)) {
        if (value == null) continue
        const field = this.element.querySelector('[name="supplier_invoice[' + key + ']"]')
        if (field) field.value = value
      }
      const currency = this.element.querySelector('[name="supplier_invoice[currency_id]"]')
      if (currency) {
        const option = Array.from(currency.options).find((item) => item.textContent.trim() === data.currency)
        if (option) currency.value = option.value
      }
      this.message("CFDI leído: " + data.concepts.length +
        " conceptos. Revisa los importes y fechas antes de guardar; el estado SAT se consulta al confirmar.")
    } catch (error) {
      this.message(error.message, true)
    }
  }

  message(text, error = false) {
    this.resultTarget.textContent = text
    this.resultTarget.classList.remove("hidden")
    this.resultTarget.classList.toggle("text-rose-700", error)
  }
}
