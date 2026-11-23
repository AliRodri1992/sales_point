import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "results", "lookupStatus", "quantity", "segment", "customer", "at", "variant", "presentation", "calculate", "status", "summary", "amount"]
  static values = { url: String, lookupUrl: String, searching: String, empty: String, error: String, calculating: String, none: String }

  disconnect() {
    clearTimeout(this.lookupTimer)
    this.lookupRequest?.abort()
    this.quoteRequest?.abort()
  }

  search() {
    clearTimeout(this.lookupTimer)
    this.lookupRequest?.abort()
    this.selectedProduct = null
    this.calculateTarget.disabled = true
    this.invalidate()
    this.dismiss()
    this.lookupStatusTarget.textContent = ""
    const q = this.searchTarget.value.trim()
    if (q.length < 2) return

    this.lookupStatusTarget.textContent = this.searchingValue
    this.lookupTimer = setTimeout(() => this.lookup(q), 250)
  }

  async lookup(query) {
    const request = new AbortController()
    this.lookupRequest = request
    const url = new URL(this.lookupUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: request.signal })
      if (!response.ok) throw new Error("Lookup failed")
      const data = await response.json()
      if (request !== this.lookupRequest || request.signal.aborted) return
      this.renderResults(data.products || [])
    } catch (error) {
      if (error.name !== "AbortError") this.lookupStatusTarget.textContent = this.errorValue
    }
  }

  renderResults(products) {
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = products.length === 0
    this.lookupStatusTarget.textContent = products.length ? "" : this.emptyValue
    products.forEach(product => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "block w-full px-4 py-3 text-left text-sm text-slate-700 hover:bg-emerald-50 focus-visible:bg-emerald-50 focus-visible:outline-none"
      button.textContent = [product.name, product.code, product.sku].filter(Boolean).join(" · ")
      button.addEventListener("click", () => this.selectProduct(product))
      button.addEventListener("keydown", event => this.navigateResults(event, button))
      this.resultsTarget.append(button)
    })
  }

  focusResults(event) {
    if (this.resultsTarget.hidden) return
    event.preventDefault()
    this.resultsTarget.firstElementChild?.focus()
  }

  navigateResults(event, button) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.dismiss()
      this.searchTarget.focus()
    } else if (["ArrowDown", "ArrowUp"].includes(event.key)) {
      event.preventDefault()
      const next = event.key === "ArrowDown" ? button.nextElementSibling : button.previousElementSibling
      const target = next || this.searchTarget
      target.focus()
    }
  }

  selectProduct(product) {
    this.selectedProduct = product
    this.searchTarget.value = product.name
    this.updateOptions(this.variantTarget, product.variants || [])
    this.updateOptions(this.presentationTarget, product.presentations || [])
    this.dismiss()
    this.calculateTarget.disabled = false
    this.searchTarget.focus()
  }

  updateOptions(select, records) {
    select.replaceChildren(new Option(this.noneValue, ""), ...records.map(record => new Option(record.name, record.id)))
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }

  dismiss() {
    this.resultsTarget.hidden = true
    this.resultsTarget.replaceChildren()
  }

  invalidate() {
    this.quoteRequest?.abort()
    this.summaryTarget.hidden = true
    this.statusTarget.textContent = ""
    this.calculateTarget.disabled = !this.selectedProduct
  }

  async calculate() {
    if (!this.selectedProduct) return
    this.invalidate()
    const request = new AbortController()
    this.quoteRequest = request
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("product_id", this.selectedProduct.id)
    url.searchParams.set("quantity", this.quantityTarget.value)
    url.searchParams.set("customer_segment", this.segmentTarget.value)
    url.searchParams.set("customer_reference", this.customerTarget.value)
    if (this.atTarget.value) url.searchParams.set("at", this.atTarget.value)
    url.searchParams.set("variant_id", this.variantTarget.value)
    url.searchParams.set("presentation_id", this.presentationTarget.value)
    this.calculateTarget.disabled = true
    this.statusTarget.textContent = this.calculatingValue
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: request.signal })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || this.errorValue)
      if (request !== this.quoteRequest || request.signal.aborted) return
      this.amountTargets.forEach(target => { target.textContent = `${data[target.dataset.amount]} ${data.currency}` })
      this.summaryTarget.hidden = false
      this.statusTarget.textContent = ""
    } catch (error) {
      if (error.name !== "AbortError") this.statusTarget.textContent = error.message || this.errorValue
    } finally {
      if (request === this.quoteRequest) this.calculateTarget.disabled = !this.selectedProduct
    }
  }
}
