import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error"]

  connect() {
    this.pending = null
    this.request = null
  }

  disconnect() {
    window.clearTimeout(this.pending)
    this.request?.abort()
  }

  schedule(event) {
    if (event.type === "input" && !event.target.matches("input[type=search], input[type=number]")) return
    if (event.type === "change" && event.target.matches("input[type=search], input[type=number]")) return

    window.clearTimeout(this.pending)
    const delay = event.target.matches("input[type=search], input[type=number]") ? 400 : 100
    this.pending = window.setTimeout(() => this.refresh(), delay)
  }

  submit(event) {
    event.preventDefault()
    window.clearTimeout(this.pending)
    this.refresh()
  }

  resetDropdown(dropdown) {
    const value = dropdown.querySelector('[data-supplier-dropdown-target="value"]')
    if (!value) return

    value.value = dropdown.dataset.supplierDropdownDefaultValue ?? ""
    const options = Array.from(dropdown.querySelectorAll('button[data-option-value]'))
    const selected = options.find((option) => option.dataset.optionValue === value.value) || options[0]
    options.forEach((option) => option.setAttribute("aria-selected", String(option === selected)))
    const label = dropdown.querySelector('[data-supplier-dropdown-target="label"]')
    if (label && selected) label.textContent = selected.querySelector("[data-option-label]")?.textContent.trim() || ""
    dropdown.open = false
  }

  removeFilter(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.filterKey
    this.element.querySelectorAll(`[name="${key}"]`).forEach((field) => {
      const dropdown = field.closest('[data-controller~="supplier-dropdown"]')
      if (dropdown) this.resetDropdown(dropdown)
      else field.value = ""
    })
    this.refresh()
  }

  clearFilters(event) {
    event.preventDefault()
    this.element.reset()
    this.element.querySelectorAll('input[type="number"], input[type="date"], input[type="search"]')
      .forEach((field) => { field.value = "" })
    this.element.querySelectorAll('[data-controller~="supplier-dropdown"]')
      .forEach((dropdown) => this.resetDropdown(dropdown))
    this.refresh()
  }

  retry(event) {
    event.preventDefault()
    this.refresh()
  }

  async refresh() {
    this.errorTarget?.classList.add('hidden')
    this.request?.abort()
    this.request = new AbortController()
    const url = new URL(this.element.action)
    const params = new URLSearchParams(new FormData(this.element))
    params.delete("page")
    url.search = params.toString()

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
        credentials: "same-origin",
        signal: this.request.signal
      })
      if (!response.ok) throw new Error(`Supplier filtering failed: ${response.status}`)
      const html = await response.text()
      if (this.request.signal.aborted) return
      window.Turbo.renderStreamMessage(html)
      window.history.replaceState(window.history.state, "", url)
      if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
    } catch (error) {
      if (error.name !== "AbortError") {
        if (this.hasErrorTarget) this.errorTarget.classList.remove("hidden")
        console.error(error)
      }
    }
  }
}
