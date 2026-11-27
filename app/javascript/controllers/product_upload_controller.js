import { Controller } from "@hotwired/stimulus"
import Uppy from "@uppy/core"
import Dashboard from "@uppy/dashboard"
import XHRUpload from "@uppy/xhr-upload"
import Spanish from "@uppy/locales/lib/es_ES.js"
import English from "@uppy/locales/lib/en_US.js"
import Korean from "@uppy/locales/lib/ko_KR.js"

export default class extends Controller {
  static targets = ["dashboard", "fallback", "input", "signedId", "status", "submit", "photoStage", "picker", "remove", "choose"]
  static values = { url: String, locale: String, busy: String, error: String, ready: String }

  connect() {
    this.originalImage = this.signedIdTarget.value
    this.originalPhotoMarkup = this.hasPhotoStageTarget ? this.photoStageTarget.innerHTML : ""
    this.previewUrl = null
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


  disconnect() {
    this.uppy?.destroy()
    this.revokePreview()
  }

  choosePhoto() {
    if (this.uploading) return
    if (this.uppy && this.hasPickerTarget) this.pickerTarget.click()
    else if (this.hasInputTarget) this.inputTarget.click()
  }

  fileChosen(event) {
    const file = event.target.files?.[0]
    if (!file) return
    this.receivePhoto(file, event.target)
    if (event.target !== this.inputTarget) event.target.value = ""
  }

  fallbackChosen(event) {
    const file = event.target.files?.[0]
    if (!file) return
    this.receivePhoto(file, event.target)
  }

  dragOver(event) {
    event.preventDefault()
    if (event.dataTransfer) event.dataTransfer.dropEffect = "copy"
  }

  dropPhoto(event) {
    event.preventDefault()
    const file = event.dataTransfer?.files?.[0]
    if (file) this.receivePhoto(file)
  }

  receivePhoto(file, sourceInput) {
    const allowed = ["image/jpeg", "image/png", "image/webp"].includes(file.type)
    if (!allowed || file.size > 5 * 1024 * 1024) {
      this.statusTarget.textContent = this.errorValue
      return
    }

    if (this.uppy) {
      // Keep the application's signed-upload flow; the custom gallery is only its visual surface.
      this.uppy.cancelAll()
      try {
        this.uppy.addFile({ name: file.name, type: file.type, data: file, source: "product-gallery" })
      } catch (_error) {
        this.uploadFailed()
        return
      }
    } else if (this.hasInputTarget && sourceInput !== this.inputTarget) {
      // Native multipart fallback when Uppy cannot initialize.
      try {
        const transfer = new DataTransfer()
        transfer.items.add(file)
        this.inputTarget.files = transfer.files
      } catch (_error) {
        this.statusTarget.textContent = this.errorValue
        return
      }
    }

    this.revokePreview()
    if (this.hasPhotoStageTarget) {
      this.previewUrl = URL.createObjectURL(file)
      const image = document.createElement("img")
      image.src = this.previewUrl
      image.alt = file.name
      this.photoStageTarget.replaceChildren(image)
    }
    if (this.hasRemoveTarget) this.removeTarget.disabled = false
    if (this.hasChooseTarget) this.chooseTarget.dataset.photoSelected = "true"
  }

  removePhoto() {
    if (this.uploading) return
    this.uppy?.cancelAll()
    if (this.hasInputTarget) this.inputTarget.value = ""
    if (this.hasPickerTarget) this.pickerTarget.value = ""
    this.signedIdTarget.value = this.originalImage
    this.revokePreview()
    if (this.hasPhotoStageTarget) this.photoStageTarget.innerHTML = this.originalPhotoMarkup
    if (this.hasRemoveTarget) this.removeTarget.disabled = true
    if (this.hasChooseTarget) delete this.chooseTarget.dataset.photoSelected
    this.statusTarget.textContent = ""
    this.failed = false
  }

  revokePreview() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }


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
