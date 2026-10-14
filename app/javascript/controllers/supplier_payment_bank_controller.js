import { Controller } from "@hotwired/stimulus"

// Only show bank accounts owned by the chosen supplier in the chosen currency.
export default class extends Controller {
  static targets = ["supplier", "currency", "account"]

  connect() {
    this.filter()
  }

  filter() {
    const supplierId = this.supplierTarget.value
    const currencyCode = this.currencyTarget.selectedOptions[0]?.textContent?.trim()

    for (const option of this.accountTarget.options) {
      if (!option.value) continue

      const allowed = option.dataset.supplierId === supplierId &&
        option.dataset.currencyCode === currencyCode

      option.hidden = !allowed
      option.disabled = !allowed
      if (!allowed && option.selected) this.accountTarget.value = ""
    }
  }
}
