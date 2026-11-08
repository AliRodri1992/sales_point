import { Controller } from "@hotwired/stimulus"

// Warn when leaving a draft with unsaved changes, including Turbo navigation.
export default class extends Controller {
  static values = { warning: String }

  connect() {
    this.dirty = false
    this.saving = false
    this.onUnload = (event) => {
      if (!this.dirty || this.saving) return
      event.preventDefault()
      event.returnValue = ""
    }
    this.onVisit = (event) => {
      if (!this.dirty || this.saving) return
      if (!window.confirm(this.warningValue)) event.preventDefault()
    }
    window.addEventListener("beforeunload", this.onUnload)
    document.addEventListener("turbo:before-visit", this.onVisit)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.onUnload)
    document.removeEventListener("turbo:before-visit", this.onVisit)
  }

  changed() {
    this.dirty = true
  }

  submitting() {
    this.saving = true
  }

  submitted(event) {
    this.saving = false
    if (event.detail.success) this.dirty = false
  }
}
