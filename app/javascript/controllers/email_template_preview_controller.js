import { Controller } from "@hotwired/stimulus"

// The preview is produced by the same sanitized renderer used for delivery.
// No changes are saved or published when previewing.
export default class extends Controller {
  static targets = ["desktop", "mobile", "subject", "plain", "status"]
  static values = { url: String }

  connect() {
    this.refresh()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refresh(), 400)
  }

  async refresh() {
    this.request?.abort()
    const request = new AbortController()
    this.request = request

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: new FormData(this.element),
        signal: request.signal
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error || "No se pudo generar la vista previa")

      this.desktopTarget.srcdoc = result.html
      this.mobileTarget.srcdoc = result.html
      this.subjectTarget.textContent = result.subject
      this.plainTarget.textContent = result.plain
      this.statusTarget.textContent = ""
    } catch (error) {
      if (error.name !== "AbortError") {
        this.statusTarget.textContent = error.message
      }
    }
  }
}
