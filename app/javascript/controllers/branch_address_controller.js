import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["country", "field"]

  connect() { this.update() }

  update() {
    const extra = this.countryTarget.selectedOptions[0]?.dataset.requiredFields || ""
    const required = new Set(["street", "city", ...extra.split(" ")])
    this.fieldTargets.forEach(field => {
      field.required = required.has(field.dataset.branchAttribute)
      field.setAttribute("aria-required", String(field.required))
    })
  }
}
