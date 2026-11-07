import { Controller } from "@hotwired/stimulus"

// Render only sanitized server previews in sandboxed iframes; never save while typing.
export default class extends Controller {
  static targets = [
    "desktop", "mobile", "subject", "plain", "status",
    "desktopPanel", "mobilePanel", "desktopButton", "mobileButton"
  ]
  static values = { url: String, error: String, loading: String }

  connect() {
    this.showDesktop()
    this.refresh()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.refresh(), 450)
  }

  showDesktop() {
    this.selectDevice("desktop")
  }

  showMobile() {
    this.selectDevice("mobile")
  }

  selectDevice(device) {
    if (!this.hasDesktopPanelTarget || !this.hasMobilePanelTarget) return

    const desktop = device === "desktop"
    this.desktopPanelTarget.classList.toggle("hidden", !desktop)
    this.mobilePanelTarget.classList.toggle("hidden", desktop)
    this.desktopButtonTarget.setAttribute("aria-pressed", String(desktop))
    this.mobileButtonTarget.setAttribute("aria-pressed", String(!desktop))
    this.desktopButtonTarget.classList.toggle("bg-white", desktop)
    this.mobileButtonTarget.classList.toggle("bg-white", !desktop)
    this.desktopButtonTarget.classList.toggle("text-emerald-800", desktop)
    this.mobileButtonTarget.classList.toggle("text-emerald-800", !desktop)
    this.desktopButtonTarget.classList.toggle("shadow-sm", desktop)
    this.mobileButtonTarget.classList.toggle("shadow-sm", !desktop)
    this.desktopButtonTarget.classList.toggle("text-slate-600", !desktop)
    this.mobileButtonTarget.classList.toggle("text-slate-600", desktop)
  }

  async refresh() {
    this.request?.abort()
    const request = new AbortController()
    this.request = request
    this.statusTarget.textContent = this.loadingValue
    this.statusTarget.classList.remove("text-rose-700")

    try {
      const dataToPreview = new FormData(this.element)
      // The editor saves with PATCH; the preview endpoint explicitly requires POST.
      dataToPreview.delete("_method")
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: dataToPreview,
        signal: request.signal
      })
      const data = await response.json().catch(() => ({}))
      if (!response.ok || typeof data.html !== "string") {
        throw new Error(this.errorValue)
      }
      if (this.request !== request) return

      this.desktopTarget.srcdoc = data.html
      this.mobileTarget.srcdoc = data.html
      this.subjectTarget.textContent = data.subject || ""
      this.plainTarget.textContent = data.plain || ""
      this.statusTarget.textContent = ""
    } catch (error) {
      if (error.name === "AbortError" || this.request !== request) return

      this.statusTarget.textContent = this.errorValue
      this.statusTarget.classList.add("text-rose-700")
    }
  }
}
