import { Controller } from "@hotwired/stimulus"

// Edit-only Uppy uploader. Reuses supplier_documents#create (Active Storage),
// leaving the supplier show-page uploader and the main edit form untouched.
const UPPY_MODULE = "https://releases.transloadit.com/uppy/v6.0.5/uppy.min.mjs"
const ALLOWED_EXTENSIONS = [".pdf", ".png", ".jpg", ".jpeg", ".txt", ".doc", ".docx", ".xls", ".xlsx", ".csv", ".xml"]
const MAX_SIZE = 10 * 1024 * 1024
const MAX_FILES = 10

export default class extends Controller {
  static targets = ["dashboard", "placeholder", "fallback", "fallbackInput", "category", "description", "status"]
  static values = { url: String, messages: Object }

  async connect() {
    this.disconnected = false
    this.setStatus(this.messagesValue.loading)
    try {
      const { Uppy, Dashboard, XHRUpload } = await import(UPPY_MODULE)
      if (this.disconnected) return

      this.uppy = new Uppy({
        autoProceed: false,
        restrictions: {
          maxNumberOfFiles: MAX_FILES,
          maxFileSize: MAX_SIZE,
          allowedFileTypes: ALLOWED_EXTENSIONS,
          minNumberOfFiles: 1
        },
        locale: {
          strings: {
            dropPasteFiles: "Arrastra tus archivos aquí o %{browseFiles}",
            browseFiles: "selecciónalos",
            uploadXFiles: "Subir %{smart_count} archivo",
            uploadXFiles_plural: "Subir %{smart_count} archivos"
          }
        }
      })
      this.uppy.use(Dashboard, {
        target: this.dashboardTarget,
        inline: true,
        width: "100%",
        height: 320,
        showProgressDetails: true,
        showRemoveButtonAfterComplete: false,
        proudlyDisplayPoweredByUppy: false,
        note: this.messagesValue.ready
      })
      this.uppy.use(XHRUpload, {
        endpoint: this.urlValue,
        method: "POST",
        formData: true,
        bundle: false,
        fieldName: "document[file]",
        allowedMetaFields: ["document[category]", "document[description]"],
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        },
        withCredentials: true,
        getResponseData: (responseText) => {
          try { return JSON.parse(responseText) } catch (_error) { return {} }
        }
      })
      this.updateMetadata()
      this.uppy.on("upload", () => this.updateMetadata())
      this.uppy.on("restriction-failed", (_file, error) => this.setStatus(error.message, true))
      this.uppy.on("upload-error", (_file, error) => this.setStatus(error.message || this.messagesValue.failed, true))
      this.uppy.on("complete", ({ successful, failed }) => {
        if (failed?.length) {
          this.setStatus(this.messagesValue.failed, true)
        } else if (successful?.length) {
          this.setStatus(this.messagesValue.success.replace("%{count}", String(successful.length)))
        }
      })
      this.placeholderTarget.remove()
      this.setStatus("")
    } catch (error) {
      console.error("Uppy could not be initialized for supplier editing", error)
      if (!this.disconnected) {
        this.fallbackTarget.hidden = false
        this.setStatus(this.messagesValue.failed, true)
      }
    }
  }

  disconnect() {
    this.disconnected = true
    this.uppy?.destroy()
    this.uppy = null
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  updateMetadata() {
    this.uppy?.setMeta({
      "document[category]": this.categoryTarget.value,
      "document[description]": this.descriptionTarget.value.trim().slice(0, 300)
    })
  }

  async fallbackUpload(event) {
    const files = Array.from(this.fallbackInputTarget.files)
    const valid = files.length > 0 && files.length <= MAX_FILES && files.every((file) => {
      const ext = `.${file.name.split(".").pop().toLowerCase()}`
      return file.size > 0 && file.size <= MAX_SIZE && ALLOWED_EXTENSIONS.includes(ext)
    })
    if (!valid) return this.setStatus(this.messagesValue.invalid, true)

    const button = event.currentTarget
    button.disabled = true
    this.setStatus(this.messagesValue.loading)

    try {
      for (const file of files) {
        const body = new FormData()
        body.append("document[file]", file)
        body.append("document[category]", this.categoryTarget.value)
        body.append("document[description]", this.descriptionTarget.value.trim().slice(0, 300))
        const response = await fetch(this.urlValue, {
          method: "POST",
          body,
          credentials: "same-origin",
          headers: { "X-CSRF-Token": this.csrfToken(), Accept: "application/json" }
        })
        if (!response.ok) throw new Error(`Upload failed: ${response.status}`)
      }
      this.fallbackInputTarget.value = ""
      this.setStatus(this.messagesValue.success.replace("%{count}", String(files.length)))
    } catch (error) {
      console.error(error)
      this.setStatus(this.messagesValue.failed, true)
    } finally {
      button.disabled = false
    }
  }

  setStatus(message, error = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message || ""
    this.statusTarget.classList.toggle("text-rose-700", error)
    this.statusTarget.classList.toggle("text-emerald-700", !error && Boolean(message))
  }
}
