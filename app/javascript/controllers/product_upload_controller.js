import { Controller } from "@hotwired/stimulus"
import Uppy from "@uppy/core"
import Dashboard from "@uppy/dashboard"
import XHRUpload from "@uppy/xhr-upload"
import Spanish from "@uppy/locales/lib/es_ES.js"
import English from "@uppy/locales/lib/en_US.js"
import Korean from "@uppy/locales/lib/ko_KR.js"

export default class extends Controller {
  static targets = ["dashboard", "fallback", "input", "signedId", "status", "submit"]
  static values = { url: String, locale: String, busy: String, error: String, ready: String }

  connect() {
    this.originalImage = this.signedIdTarget.value
    try {
      this.uppy = new Uppy({
        autoProceed: true,
        locale: { es: Spanish, en: English, ko: Korean }[this.localeValue] || English,
        restrictions: { maxNumberOfFiles: 1, maxFileSize: 5 * 1024 * 1024, allowedFileTypes: ["image/jpeg", "image/png", "image/webp"] }
      })
      this.uppy.use(Dashboard, { target: this.dashboardTarget, inline: true, height: 280, width: "100%", proudlyDisplayPoweredByUppy: false, singleFileFullScreen: true, hideProgressAfterFinish: true, doneButtonHandler: null })
      this.uppy.use(XHRUpload, { endpoint: this.urlValue, method: "POST", formData: true, fieldName: "file", allowedMetaFields: false,
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "", Accept: "application/json" } })
      this.uppy.on("upload", () => this.setBusy(true))
      this.uppy.on("file-added", () => this.setBusy(true))
      this.uppy.on("upload-success", (_file, response) => {
        if (!response.body?.signed_id) return this.uploadFailed()
        this.signedIdTarget.value = response.body.signed_id
        this.setBusy(false)
        this.statusTarget.textContent = this.readyValue
      })
      this.uppy.on("upload-error", () => this.uploadFailed())
      this.uppy.on("error", () => this.uploadFailed())
      this.uppy.on("file-removed", () => {
        this.signedIdTarget.value = this.originalImage
        this.setBusy(false)
        this.statusTarget.textContent = ""
      })
      this.inputTarget.disabled = true
      this.fallbackTarget.hidden = true
      this.dashboardTarget.hidden = false
    } catch (_error) {
      this.uppy?.destroy()
      this.uppy = null
      this.inputTarget.disabled = false
      this.fallbackTarget.hidden = false
      this.dashboardTarget.hidden = true
    }
  }

  disconnect() { this.uppy?.destroy() }

  guardSubmit(event) {
    if (!this.uploading && !this.failed) return
    event.preventDefault()
    this.statusTarget.textContent = this.uploading ? this.busyValue : this.errorValue
    this.statusTarget.focus()
  }

  setBusy(value) {
    this.uploading = value
    this.failed = false
    this.submitTargets.forEach((button) => { button.disabled = value })
    this.statusTarget.textContent = value ? this.busyValue : ""
  }

  uploadFailed() {
    this.setBusy(false)
    this.failed = true
    this.statusTarget.textContent = this.errorValue
  }
}
