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

  removeFilter(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.filterKey
    const fields = this.element.querySelectorAll(`[name="${key}"]`)
    fields.forEach((field) => {
      if (field.type === "radio") {
        field.checked = field.value === "all" || field.value === ""
      } else {
        field.value = ""
      }
    })
    const dropdown = fields[0]?.closest('[data-controller~="supplier-dropdown"]')
    if (dropdown) {
      const selected = dropdown.querySelector("input:checked")
      const label = selected?.closest("label")?.querySelector("[data-option-label]")
      if (label) dropdown.querySelector('[data-supplier-dropdown-target="label"]').textContent = label.textContent.trim()
    }
    this.refresh()
  }

  clearFilters(event) {
    event.preventDefault()
    this.element.reset()
    this.element.querySelectorAll('input[type="number"], input[type="date"], input[type="search"]').forEach((field) => { field.value = "" })
    this.element.querySelectorAll('input[type="radio"]').forEach((field) => { field.checked = field.value === "all" || field.value === "" })
    this.element.querySelectorAll('[data-controller~="supplier-dropdown"]').forEach((dropdown) => {
      const selected = dropdown.querySelector("input:checked")
      const label = selected?.closest("label")?.querySelector("[data-option-label]")
      if (label) dropdown.querySelector('[data-supplier-dropdown-target="label"]').textContent = label.textContent.trim()
    })
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
