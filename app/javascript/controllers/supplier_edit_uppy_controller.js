import { Controller } from "@hotwired/stimulus"

// Edit-only Uppy uploader. Reuses supplier_documents#create (Active Storage),
// leaving the supplier show-page uploader and the main edit form untouched.
const UPPY_MODULE = "https://releases.transloadit.com/uppy/v6.0.5/uppy.min.mjs"
const ALLOWED_EXTENSIONS = [".pdf", ".png", ".jpg", ".jpeg", ".txt", ".doc", ".docx", ".xls", ".xlsx", ".csv", ".xml"]
const MAX_SIZE = 10 * 1024 * 1024
const MAX_FILES = 10

export default class extends Controller {
  static targets = ["dashboard", "placeholder", "placeholderMessage", "retryButton", "category", "description", "status", "statusMessage"]
  static values = { url: String, messages: Object }

  connect() {
    this.disconnected = false
    this.initialized = false
    this.loading = false
    this.retryAttempt = 0
    this.section = this.element.closest('[data-supplier-form-target="step"]')
    this.visibilityObserver = new MutationObserver(() => this.initializeWhenVisible())
    if (this.section) {
      this.visibilityObserver.observe(this.section, {
        attributes: true, attributeFilter: ["hidden", "class"]
      })
    }
    this.initializeWhenVisible()
  }

  initializeWhenVisible() {
    if (this.initialized || this.loading || this.section?.hidden ||
        this.section?.classList.contains("hidden")) return
    this.visibilityObserver?.disconnect()
    this.initialize()
  }

  retry() {
    if (this.loading || this.disconnected) return
    this.retryAttempt += 1
    this.retryButtonTarget.hidden = true
    this.placeholderMessageTarget.textContent = this.messagesValue.loading
    this.initialize()
  }

  async initialize() {
    this.loading = true
    this.setStatus("")
    try {
      // A fresh URL lets the user retry a failed browser module fetch.
      const moduleUrl = this.retryAttempt ? `${UPPY_MODULE}?retry=${this.retryAttempt}` : UPPY_MODULE
      const { Uppy, Dashboard, XHRUpload } = await import(moduleUrl)
      if (this.disconnected) return
      if (![Uppy, Dashboard, XHRUpload].every((plugin) => typeof plugin === "function")) {
        throw new Error("The Uppy CDN bundle is missing the required plugins")
      }

      const language = document.documentElement.lang?.toLowerCase() || "es"
      const uploaderCopy = language.startsWith("ko")
        ? {
            dropPasteFiles: "파일을 드래그하거나 %{browseFiles}", browseFiles: "찾아보기",
            uploadXFiles: "파일 %{smart_count}개 업로드", uploadXFiles_plural: "파일 %{smart_count}개 업로드"
          }
        : language.startsWith("en")
          ? { dropPasteFiles: "Drop files here or %{browseFiles}", browseFiles: "browse" }
          : {
              dropPasteFiles: "Arrastra tus archivos aquí o %{browseFiles}", browseFiles: "selecciónalos",
              uploadXFiles: "Subir %{smart_count} archivo", uploadXFiles_plural: "Subir %{smart_count} archivos"
            }

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
            ...uploaderCopy
          }
        }
      })
      this.uppy.use(Dashboard, {
        target: this.dashboardTarget,
        inline: true,
        width: "100%",
        height: 320,
        showProgressDetails: true,
        // The completed StatusBar otherwise covers the Dashboard loading/progress area.
        // Keep live upload progress and display completion only in our separate feedback row.
        hideProgressAfterFinish: true,
        doneButtonHandler: null,
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
        withCredentials: true
      })
      this.updateMetadata()
      this.uppy.on("upload", () => {
        this.setStatus("")
        this.updateMetadata()
      })
      this.uppy.on("restriction-failed", (_file, error) => this.setStatus(error.message, true))
      this.uppy.on("upload-error", (_file, error) => this.setStatus(error.message || this.messagesValue.failed, true))
      this.uppy.on("complete", ({ successful, failed }) => {
        if (failed?.length) {
          this.setStatus(this.messagesValue.failed, true)
        } else if (successful?.length) {
          this.setStatus(this.messagesValue.success.replace("%{count}", String(successful.length)))
        }
      })
      this.initialized = true
      if (this.hasPlaceholderTarget) this.placeholderTarget.remove()
      this.setStatus("")
    } catch (error) {
      console.error("Uppy could not be initialized for supplier editing", error)
      if (!this.disconnected) {
        try { this.uppy?.destroy() } catch (cleanupError) {
          console.warn("Unable to dispose Uppy after initialization error", cleanupError)
        }
        this.uppy = null
        // One surface only: keep Uppy’s host, with a retry action inside it.
        this.dashboardTarget.replaceChildren(this.placeholderTarget)
        this.placeholderTarget.hidden = false
        this.placeholderMessageTarget.textContent = this.messagesValue.unavailable
        this.retryButtonTarget.hidden = false
        this.setStatus("")
      }
    } finally {
      this.loading = false
    }
  }

  disconnect() {
    this.disconnected = true
    this.visibilityObserver?.disconnect()
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

  setStatus(message, error = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.hidden = !message
    this.statusTarget.dataset.state = error ? "error" : "success"
    if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = message || ""
  }
}
