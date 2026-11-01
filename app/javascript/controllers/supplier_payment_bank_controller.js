import { Controller } from "@hotwired/stimulus"

// Fetch only bank accounts for the selected supplier and currency.
// Other suppliers' financial data must never be embedded in the form markup.
export default class extends Controller {
  static targets = ["supplier", "currency", "account"]
  static values = { url: String }

  connect() {
    this.requestVersion = 0
    this.pendingRequest = null
    this.filter()
  }

  disconnect() {
    this.pendingRequest?.abort()
  }

  async filter() {
    if (!this.hasSupplierTarget || !this.hasCurrencyTarget || !this.hasAccountTarget) return

    const supplierId = this.supplierTarget.value
    const currencyId = this.currencyTarget.value
    const account = this.accountTarget
    const previousValue = account.value
    const version = ++this.requestVersion

    this.pendingRequest?.abort()
    this.pendingRequest = null
    this.replaceOptions([], previousValue)

    if (!supplierId || !currencyId || !this.hasUrlValue) return

    const controller = new AbortController()
    this.pendingRequest = controller
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("supplier_id", supplierId)
    url.searchParams.set("currency_id", currencyId)

    try {
      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: controller.signal
      })
      if (!response.ok) throw new Error("Unable to load bank accounts")
      const data = await response.json()
      if (version !== this.requestVersion) return
      this.replaceOptions(data.accounts || [], previousValue)
    } catch (error) {
      if (error.name !== "AbortError" && version === this.requestVersion) {
        this.replaceOptions([], previousValue)
      }
    }
  }

  replaceOptions(options, previousValue) {
    const account = this.accountTarget
    const blank = new Option("", "")
    const entries = options.map(({ id, label }) => new Option(label, String(id)))
    account.replaceChildren(blank, ...entries)
    if (entries.some((entry) => entry.value === previousValue)) account.value = previousValue
    else account.value = ""
    account.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
