import { Controller } from "@hotwired/stimulus"

// Optional suggestions for Mexican postal codes, without overriding user edits.
export default class extends Controller {
  static targets = ["status", "neighborhoods", "choices", "choicesWrapper"]
  static values = {
    url: String,
    loading: String,
    available: String,
    notFound: String,
    unavailable: String,
    choicePlaceholder: String
  }

  connect() {
    this.lastFilled = {}
    this.request = null
    this.timer = null
    this.lookup()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  field(name) {
    return this.element.querySelector('[data-supplier-postal-field="' + name + '"]') ||
      this.element.querySelector('[name="address[' + name + ']"]')
  }

  isMexico() {
    const country = this.field("country_id")
    return country?.selectedOptions[0]?.dataset.countryCode === "MX"
  }

  input(event) {
    if (event.target !== this.field("postal_code") && event.target !== this.field("country_id")) return

    this.clearPreviousSuggestions()
    this.lookup()
  }

  clearPreviousSuggestions() {
    for (const name of ["state", "city"]) {
      const field = this.field(name)
      if (field && this.lastFilled[name] && field.value === this.lastFilled[name]) {
        field.value = ""
        field.dispatchEvent(new Event("input", { bubbles: true }))
      }
      delete this.lastFilled[name]
    }
  }

  lookup() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.neighborhoodsTarget.replaceChildren()
    if (this.hasChoicesTarget) {
      this.choicesTarget.replaceChildren()
      this.choicesTarget.dispatchEvent(new Event("change", { bubbles: true }))
      if (this.hasChoicesWrapperTarget) this.choicesWrapperTarget.classList.add("hidden")
    }
    this.statusTarget.textContent = ""
    if (!this.isMexico()) return

    const postal = this.field("postal_code")?.value.trim() || ""
    if (!/^\d{5}$/.test(postal)) return

    this.statusTarget.textContent = this.loadingValue
    this.timer = setTimeout(() => this.fetch(postal), 350)
  }

  async fetch(postal) {
    const controller = new AbortController()
    this.request = controller
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("postal_code", postal)
    url.searchParams.set("country", "MX")
    try {
      const response = await window.fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: controller.signal
      })
      if (!response.ok) throw new Error("Postal lookup unavailable")
      const data = await response.json()
      if (controller !== this.request || !this.isMexico() || this.field("postal_code").value !== postal) return
      this.displaySuggestions(data)
    } catch (error) {
      if (error.name !== "AbortError" && controller === this.request) {
        this.statusTarget.textContent = this.unavailableValue
      }
    } finally {
      if (controller === this.request) this.request = null
    }
  }

  displaySuggestions(data) {
    if (!data.found) {
      this.statusTarget.textContent = this.notFoundValue
      return
    }
    this.fillIfUnchanged("state", data.state)
    this.fillIfUnchanged("city", data.municipality)
    for (const name of data.neighborhoods || []) {
      const option = document.createElement("option")
      option.value = name
      this.neighborhoodsTarget.append(option)
    }
    if (this.hasChoicesTarget && (data.neighborhoods || []).length) {
      const placeholder = document.createElement("option")
      placeholder.value = ""
      placeholder.textContent = this.choicePlaceholderValue
      this.choicesTarget.append(placeholder)
      for (const neighborhood of data.neighborhoods) {
        const option = document.createElement("option")
        option.value = neighborhood
        option.textContent = neighborhood
        this.choicesTarget.append(option)
      }
      if (this.hasChoicesWrapperTarget) this.choicesWrapperTarget.classList.remove("hidden")
      this.choicesTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    this.statusTarget.textContent = this.availableValue
  }

  chooseNeighborhood(event) {
    const value = event.currentTarget.value
    const field = this.field("neighborhood")
    if (!field || !value) return
    field.value = value
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }

  fillIfUnchanged(fieldName, suggestion) {
    const field = this.field(fieldName)
    if (!field || !suggestion) return
    if (field.value.trim() && field.value !== this.lastFilled[fieldName]) return

    field.value = suggestion
    this.lastFilled[fieldName] = suggestion
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
