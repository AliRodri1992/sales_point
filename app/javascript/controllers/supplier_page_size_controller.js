import { Controller } from "@hotwired/stimulus"
import { saveTablePagePreference } from "../lib/table_page_preferences"

// Preference persistence and table navigation share the branded Deltín loader.
export default class extends Controller {
  connect() {
    this.onPageShow = () => { this.submitting = false }
    window.addEventListener("pageshow", this.onPageShow)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.onPageShow)
  }

  async apply(event) {
    if (!event.target.matches('select[name="per_page"]') || this.submitting) return

    this.submitting = true
    document.dispatchEvent(new CustomEvent("admin:action-loading", {
      detail: { message: this.element.dataset.loadingMessage }
    }))

    try {
      await saveTablePagePreference("suppliers", event.target.value)
    } catch (error) {
      console.warn("Supplier page size was not saved", error)
      document.dispatchEvent(new CustomEvent("admin:action-loading", {
        detail: { active: false }
      }))
      this.submitting = false
      const english = document.documentElement.lang?.toLowerCase().startsWith("en")
      const title = english ? "Could not save your preference" : "No se pudo guardar tu preferencia"
      const message = english ? "Please try again." : "Intenta nuevamente."
      if (window.Swal) window.Swal.fire({ icon: "error", title, text: message })
      else window.alert(`${title}. ${message}`)
      return
    }

    this.element.requestSubmit()
  }
}
