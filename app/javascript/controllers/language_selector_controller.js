import { Controller } from "@hotwired/stimulus"
import { closeDashboardSelectors, openDashboardSelector } from "./selector_coordinator"

export default class extends Controller {
  static targets = ["dropdown", "status", "button"]

  connect() {
    this.onOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    document.addEventListener("click", this.onOutsideClick)
    this.button?.setAttribute("aria-expanded", "false")
  }

  disconnect() {
    document.removeEventListener("click", this.onOutsideClick)
  }

  get button() {
    return this.hasButtonTarget ? this.buttonTarget : this.element.querySelector("#languageSelectorButton")
  }

  get choices() {
    return Array.from(this.dropdownTarget.querySelectorAll("button[data-language]"))
  }

  toggle(event) {
    event.preventDefault()
    if (!this.hasDropdownTarget) return
    if (!this.dropdownTarget.classList.contains("hidden")) {
      this.close()
      return
    }
    openDashboardSelector(this.element)
    this.dropdownTarget.classList.remove("hidden")
    this.button?.setAttribute("aria-expanded", "true")
    this.choices.find((choice) => choice.getAttribute("aria-pressed") === "true")?.focus()
    if (this.element.querySelector("#language_selector_content") &&
        window.location.pathname.startsWith("/admin/")) this.refreshDropdownContent()
  }

  close() {
    if (!this.hasDropdownTarget) return
    this.dropdownTarget.classList.add("hidden")
    this.button?.setAttribute("aria-expanded", "false")
  }

  keydown(event) {
    if (!this.hasDropdownTarget || this.dropdownTarget.classList.contains("hidden")) return
    if (event.key === "Escape") {
      event.preventDefault()
      event.stopPropagation()
      this.close()
      this.button?.focus()
      return
    }
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return
    const choices = this.choices
    if (!choices.length) return
    event.preventDefault()
    const index = choices.indexOf(document.activeElement)
    const direction = event.key === "ArrowDown" ? 1 : -1
    choices[(index + direction + choices.length) % choices.length]?.focus()
  }

  async refreshDropdownContent() {
    try {
      const response = await fetch("/admin/languages/content", {
        method: "GET", headers: { Accept: "text/html" }
      })
      if (!response.ok) return
      const html = await response.text()
      const incoming = new DOMParser().parseFromString(html, "text/html").getElementById("language_selector_content")
      const existing = this.element.querySelector("#language_selector_content")
      if (incoming && existing) existing.innerHTML = incoming.innerHTML
    } catch (error) {
      console.error("Error refreshing language dropdown:", error)
    }
  }

  async select(event) {
    event.stopPropagation()
    const language = event.currentTarget.dataset.language
    if (!language) return
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    try {
      const response = await fetch("/language", {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
        body: JSON.stringify({ language })
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      closeDashboardSelectors()
      window.location.reload()
    } catch (error) {
      console.error("Language change error:", error)
      const title = this.element.dataset.languageErrorTitle
      const message = this.element.dataset.languageErrorMessage
      if (this.hasStatusTarget) this.statusTarget.textContent = message
      window.Swal?.fire({ icon: "error", title, text: message })
      this.close()
      this.button?.focus()
    }
  }
}
