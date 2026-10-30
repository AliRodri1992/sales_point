import { Controller } from "@hotwired/stimulus"
import { saveTablePagePreference } from "../lib/table_page_preferences"

// Keep the size selector responsive and display progress while Turbo navigates.
export default class extends Controller {
  connect() {
    this.onPageShow = () => this.hideLoader()
    window.addEventListener("pageshow", this.onPageShow)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.onPageShow)
  }

  async apply(event) {
    if (!event.target.matches('select[name="per_page"]')) return
    if (this.submitting) return

    this.submitting = true
    const loader = document.getElementById("supplier-page-size-loader")
    if (loader) {
      loader.hidden = false
      loader.classList.remove("hidden")
      loader.setAttribute("aria-hidden", "false")
    }

    try {
      await saveTablePagePreference("suppliers", event.target.value)
    } catch (error) {
      console.warn("Supplier page size was not saved", error)
    }
    this.element.requestSubmit()
  }

  hideLoader() {
    const loader = document.getElementById("supplier-page-size-loader")
    if (loader) {
      loader.hidden = true
      loader.classList.add("hidden")
      loader.setAttribute("aria-hidden", "true")
    }
    this.submitting = false
  }
}
