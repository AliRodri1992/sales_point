import { Controller } from "@hotwired/stimulus"

// Only show bank accounts owned by the chosen supplier in the chosen currency.
export default class extends Controller {
  static targets = ["supplier", "currency", "account"]

  connect() {
    this.filter()
  }

  filter() {
    if (!this.hasSupplierTarget || !this.hasCurrencyTarget || !this.hasAccountTarget) return

    const supplierId = this.supplierTarget.value
    const currencyCode = this.currencyTarget.selectedOptions[0]?.textContent?.trim()
    const account = this.accountTarget
    const previousValue = account.value

    for (const option of account.options) {
      if (!option.value) continue

      const allowed = option.dataset.supplierId === supplierId &&
        option.dataset.currencyCode === currencyCode

      option.hidden = !allowed
      option.disabled = !allowed
    }

    const selected = account.selectedOptions[0]
    if (selected?.disabled || selected?.hidden) account.value = ""

    // Changing a native select programmatically does not emit "change".
    // Notify the branded dropdown and any other dependent form controls.
    if (account.value !== previousValue) {
      account.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}
