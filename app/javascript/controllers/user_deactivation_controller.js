import { Controller } from "@hotwired/stimulus"

// One accessible, reusable dialog for the directory and the user detail.
// The transition, permissions and mandatory reason are validated by Rails.
export default class extends Controller {
  static targets = ["dialog", "form", "account", "reason", "errors"]

  open(event) {
    const button = event.currentTarget
    this.returnFocus = button
    this.formTarget.action = button.dataset.deactivationUrl
    this.accountTarget.textContent = button.dataset.deactivationAccount || ""
    this.reasonTarget.value = ""
    this.reasonTarget.removeAttribute("aria-invalid")
    this.errorsTarget.replaceChildren()
    this.dialogTarget.showModal()
    this.reasonTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  closed() {
    this.returnFocus?.isConnected && this.returnFocus.focus()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  submissionFinished(event) {
    if (event.detail.success) {
      this.close()
      return
    }

    if (event.detail.fetchResponse?.statusCode === 422) {
      const reasonError = this.errorsTarget.querySelector("[data-deactivation-reason-error]")
      if (reasonError) {
        this.reasonTarget.setAttribute("aria-invalid", "true")
      } else {
        this.reasonTarget.removeAttribute("aria-invalid")
      }
      if (reasonError) {
        this.reasonTarget.focus()
      } else {
        this.errorsTarget.focus()
      }
      return
    }

    this.reasonTarget.removeAttribute("aria-invalid")
    this.errorsTarget.textContent = this.errorsTarget.dataset.requestErrorMessage
    this.errorsTarget.focus()
  }
}
