import { Controller } from "@hotwired/stimulus"

// Suggests the SAT bank using the first three CLABE digits, without transmitting
// or exposing the full CLABE in the page beyond its protected input.
export default class extends Controller {
  static targets = ["clabe", "bank"]

  lookup() {
    const clabe = this.clabeTarget.value.replace(/\s/g, "")
    if (!/^\d{18}$/.test(clabe)) return

    const bankCode = clabe.slice(0, 3)
    const available = Array.from(this.bankTarget.options).some(({ value }) => value === bankCode)
    if (available) {
      this.bankTarget.value = bankCode
      this.bankTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}
