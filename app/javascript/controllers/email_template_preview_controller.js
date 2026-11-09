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
      // Saving uses PATCH; preview is a POST and never persists the draft.
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
      if (this.request !== request) return
      if (!response.ok || typeof data.html !== "string") {
        // Reconcile only when the server actually returned model validation errors.
        if (data.errors) this.syncErrors(data.errors)
        throw new Error(data.error || this.errorValue)
      }
      this.syncErrors({})
      this.desktopTarget.srcdoc = data.html
      this.mobileTarget.srcdoc = data.html
      this.subjectTarget.textContent = data.subject || ""
      this.plainTarget.textContent = data.plain || ""
      this.statusTarget.textContent = ""
    } catch (error) {
      if (error.name === "AbortError" || this.request !== request) return
      this.desktopTarget.srcdoc = ""
      this.mobileTarget.srcdoc = ""
      this.subjectTarget.textContent = ""
      this.plainTarget.textContent = ""
      this.statusTarget.textContent = error.message || this.errorValue
      this.statusTarget.classList.add("text-rose-700")
    }
  }

  // Keep the original 422 feedback while the request is pending. Reuse matching
  // server messages, replace changed ones, and clear stale errors on valid preview.
  syncErrors(errors) {
    this.element.querySelectorAll("[data-email-preview-field-error]").forEach(node => node.remove())
    this.element.querySelectorAll('[name^="email_template_version["]').forEach(field => {
      const inputName = field.name.match(/^email_template_version\[([^\]]+)\]$/)?.[1]
      if (!inputName || inputName === "lock_version") return
      const attribute = inputName === "allowed_variables_csv" ? "allowed_variables" : inputName
      const messages = Array.isArray(errors?.[attribute]) ? [...new Set(errors[attribute])] : []
      const label = this.element.querySelector('label[for="' + field.id + '"]')
      const title = (label?.textContent || attribute).replace("*", "").trim()
      const existing = [...this.element.querySelectorAll("[data-server-field-error]")]
        .filter(node => node.dataset.validationAttribute === attribute)
      const expected = messages.map(message => (title + " " + message).trim())
      const keepServer = existing.length > 0 && existing.length === expected.length &&
        existing.every((node, index) => node.textContent.trim() === expected[index])
      if (!keepServer) existing.forEach(node => node.remove())
      // Retain hint descriptions, excluding IDs of removed errors.
      const ids = new Set((field.getAttribute("aria-describedby") || "").split(/\s+/)
        .filter(id => id && document.getElementById(id)))
      if (messages.length) {
        if (!keepServer) {
          const prefix = field.id.replace(/_allowed_variables_csv$/, "_allowed_variables") + "_error"
          let last = field
          messages.forEach((message, index) => {
            const node = document.createElement("p")
            node.dataset.emailPreviewFieldError = "true"
            node.id = index === 0 ? prefix : prefix + "_" + (index + 1)
            node.setAttribute("role", "alert")
            node.className = "mt-1 text-xs text-rose-700"
            node.textContent = (title + " " + message).trim()
            last.insertAdjacentElement("afterend", node)
            last = node
            ids.add(node.id)
          })
        }
        field.setAttribute("aria-invalid", "true")
        this.markInvalid(field)
      } else {
        field.setAttribute("aria-invalid", "false")
        this.restoreValidStyle(field)
      }
      if (ids.size) field.setAttribute("aria-describedby", [...ids].join(" "))
      else field.removeAttribute("aria-describedby")
    })
  }

  markInvalid(field) {
    field.classList.remove("border-slate-300", "border-slate-700", "focus:border-emerald-500", "focus:ring-emerald-100")
    field.classList.add("border-rose-400", "focus:border-rose-500", "focus:ring-rose-100")
  }

  restoreValidStyle(field) {
    field.classList.remove("ring-1", "ring-rose-400", "border-rose-400", "bg-rose-50/40",
      "focus:border-rose-500", "focus:ring-rose-100", "focus:ring-rose-200")
    field.classList.add(field.id.endsWith("_html_body") ? "border-slate-700" : "border-slate-300",
      "focus:border-emerald-500", "focus:ring-emerald-100")
    if (field.id.endsWith("_text_body")) field.classList.add("bg-slate-50/60")
  }
}
