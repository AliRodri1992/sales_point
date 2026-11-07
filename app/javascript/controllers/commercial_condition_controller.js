import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { this.refresh() }

  refresh() {
    const kind = this.element.querySelector('select[name$="[kind]"]').value
    const fields = { product_id: "product", category_id: "category", quantity: "min_quantity", amount: "min_subtotal", customer_segment: "customer_segment" }
    Object.entries(fields).forEach(([field, requiredKind]) => {
      const input = this.element.querySelector(`[name$="[${field}]"]`)
      if (input) input.closest(".catalog-field").hidden = kind !== requiredKind
    })
  }
}
