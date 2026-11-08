import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { confirmationOptions } from "./swal_confirm_controller"

// Warn when leaving a draft with unsaved changes, including Turbo navigation.
export default class extends Controller {
  static values = { warning: String }

  connect() {
    this.dirty = false
    this.saving = false
    this.confirmationPending = false
    this.onUnload = (event) => {
      if (!this.dirty || this.saving) return
      event.preventDefault()
      event.returnValue = ""
    }
    this.onVisit = (event) => {
      if (!this.dirty || this.saving) return

      event.preventDefault()
      if (this.confirmationPending) return

      const destination = event.detail.url
      this.confirmationPending = true
      const confirmation = window.Swal
        ? window.Swal.fire(confirmationOptions(this.warningValue, this.element))
            .then(result => result.isConfirmed)
        : Promise.resolve(window.confirm(this.warningValue))

      confirmation.then(confirmed => {
        if (!confirmed || !this.element.isConnected) return

        this.dirty = false
        Turbo.visit(destination)
      }).finally(() => {
        this.confirmationPending = false
      })
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
