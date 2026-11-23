import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "status", "results", "selection"]
  static values = { url: String, loading: String, empty: String, failed: String }

  disconnect() {
    this.cancel()
  }

  cancel() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  clear() {
    this.cancel()
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = true
    this.resultsTarget.setAttribute("aria-busy", "false")
    this.statusTarget.textContent = ""
  }

  search() {
    this.clear()
    if (this.hasSelectionTarget) this.selectionTarget.value = ""
    const query = this.searchTarget.value.trim()
    if (!query) return
    this.timer = setTimeout(() => this.load(query), 180)
  }

  async load(query) {
    const request = new AbortController()
    this.request = request
    this.resultsTarget.setAttribute("aria-busy", "true")
    this.statusTarget.textContent = this.loadingValue
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, { signal: request.signal, headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error("lookup")
      const { products } = await response.json()
      if (request.signal.aborted) return
      this.products = products
      this.resultsTarget.replaceChildren(...products.map((product, index) => this.result(product, index)))
      this.resultsTarget.hidden = !products.length
      this.statusTarget.textContent = products.length ? "" : this.emptyValue
    } catch {
      if (!request.signal.aborted) this.statusTarget.textContent = this.failedValue
    } finally {
      if (!request.signal.aborted) this.resultsTarget.setAttribute("aria-busy", "false")
    }
  }

  result(product, index) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "flex w-full min-h-11 items-center justify-between gap-3 border-b border-slate-100 px-3 py-2 text-left text-sm hover:bg-slate-50"
    button.dataset.priceListLookupResult = index
    button.dataset.action = "price-list-lookup#choose"
    const name = document.createElement("strong")
    name.textContent = product.name
    const code = document.createElement("span")
    code.className = "text-xs text-slate-600"
    code.textContent = product.sku || product.code
    button.append(name, code)
    return button
  }

  choose(event) {
    const product = this.products[Number(event.currentTarget.dataset.priceListLookupResult)]
    this.clear()
    this.searchTarget.value = this.hasSelectionTarget ? product.name : ""
    if (this.hasSelectionTarget) this.selectionTarget.value = product.id
    this.searchTarget.focus()
    this.dispatch("selected", { detail: { product } })
  }

  navigate(event) {
    if (event.isComposing) return
    const buttons = [...this.resultsTarget.children]
    if (event.key === "Escape") {
      this.clear()
      this.searchTarget.focus()
    } else if (buttons.length && ["ArrowDown", "ArrowUp"].includes(event.key)) {
      event.preventDefault()
      const index = buttons.indexOf(document.activeElement)
      const next = event.key === "ArrowDown" ? index + 1 : index < 0 ? buttons.length - 1 : index - 1
      buttons[(next + buttons.length) % buttons.length].focus()
    } else if (!this.hasSelectionTarget && event.key === "Enter" && event.target === this.searchTarget) {
      event.preventDefault()
      buttons[0]?.click()
    }
  }

  leave(event) {
    if (event.relatedTarget && !this.element.contains(event.relatedTarget)) this.clear()
  }
}
