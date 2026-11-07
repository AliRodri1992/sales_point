import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "result", "variant", "presentation", "priceList", "segment"]
  static values = { url: String }

  disconnect() { this.abort?.abort() }

  async calculate() {
    this.abort?.abort()
    this.abort = new AbortController()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("quantity", this.quantityTarget.value)
    const options = { variant_id: this.variantTarget.value, presentation_id: this.presentationTarget.value, price_list_id: this.priceListTarget.value, customer_segment: this.segmentTarget.value }
    Object.entries(options).forEach(([key, value]) => { if (value) url.searchParams.set(key, value) })
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.abort.signal })
      if (!response.ok) throw new Error("quote")
      const result = await response.json()
      const amount = new Intl.NumberFormat(document.documentElement.lang, { style: "currency", currency: result.currency }).format(result.total)
      this.resultTarget.textContent = [amount, result.promotion].filter(Boolean).join(" · ")
    } catch (error) {
      if (error.name !== "AbortError") this.resultTarget.textContent = this.resultTarget.dataset.error
    }
  }
}
