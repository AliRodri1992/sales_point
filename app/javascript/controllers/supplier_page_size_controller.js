import { Controller } from "@hotwired/stimulus"

// Keep the size selector responsive and display progress while Turbo navigates.
export default class extends Controller {
  connect() {
    this.onPageShow = () => this.hideLoader()
    this.onBeforeCache = () => this.hideLoader()
    this.onSubmitEnd = (event) => {
      if (event.target === this.element && !event.detail?.success) this.hideLoader()
    }
    window.addEventListener("pageshow", this.onPageShow)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.onPageShow)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  apply(event) {
    if (!event.target.matches('select[name="per_page"]')) return
    if (this.submitting) return

    this.submitting = true
    const loader = document.getElementById("supplier-page-size-loader")
    if (loader) {
      loader.hidden = false
      loader.classList.remove("hidden")
      loader.setAttribute("aria-hidden", "false")
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
