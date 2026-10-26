import { Controller } from "@hotwired/stimulus"

// Browses supplier attachments locally; every preview uses the authorized Rails endpoint.
export default class extends Controller {
  static targets = [
    "categorySelect", "search", "status", "date", "card", "noResults", "filterError",
    "uploadForm", "uploadInput", "uploadSelection", "uploadSubmit", "uploadNames",
    "uploadCount", "uploadError", "dropzone", "queuedList", "queuedDialog",
    "queuedClose", "queuedImage", "queuedFrame", "queuedText", "queuedUnsupported",
    "queuedName",
    "range", "page", "previous", "next", "previewContent", "previewEmpty",
    "previewName", "previewType", "previewSize", "previewDate", "previewDescription",
    "previewFrame", "previewImage", "previewText", "unsupported", "previewError",
    "dialog", "closeButton",
    "download", "open", "replaceForm", "editForm", "editCategory", "editStatus",
    "editDescription", "replaceDetails", "editDetails"
  ]

  static values = {
    rangeLabel: String,
    filesSelected: String,
    invalidFiles: String,
    pageSize: { type: Number, default: 8 },
    serverPage: Number,
    serverTotal: Number,
    serverFiltered: Boolean,
    nextUrl: String,
    previousUrl: String
  }

  connect() {
    this.filterRequest = null
    this.queuedFiles = []
    this.queuedPreviewTrigger = null
    this.queuedDialogOverflow = null
    if (this.hasUploadInputTarget) this.filesChanged()
    if (!this.hasCardTarget) return

    this.pageNumber = this.hasServerPageValue ? this.serverPageValue : 1
    this.selectedId = null
    this.previewRequest = null
    this.lastTrigger = null
    this.scrollWasLocked = false
    this.refresh()
  }

  disconnect() {
    this.closeQueuedPreview({ restoreFocus: false })
    this.revokeQueuedUrls()
    this.closePreview({ restoreFocus: false })
    this.cancelPreview()
    if (this.filterTimer) clearTimeout(this.filterTimer)
    this.filterRequest?.abort()
  }

  filter(event) {
    if (this.hasCardTarget) this.refresh()
    if (this.hasServerTotalValue && this.serverTotalValue <= this.pageSizeValue &&
      !this.serverFilteredValue) return

    if (this.filterTimer) clearTimeout(this.filterTimer)
    this.filterTimer = setTimeout(() => this.applyServerFilters(), event?.type === "input" ? 350 : 0)
  }

  applyServerFilters() {
    const url = new URL(window.location.href)
    url.searchParams.set("tab", "documents")
    const filters = {
      documents_q: this.searchTarget.value.trim(),
      documents_category: this.categorySelectTarget.value,
      documents_status: this.statusTarget.value,
      documents_days: this.dateTarget.value
    }
    for (const [name, value] of Object.entries(filters)) {
      if (value) url.searchParams.set(name, value)
      else url.searchParams.delete(name)
    }
    url.searchParams.delete("documents_page")
    this.loadDocuments(url, { restoreSearch: true })
  }

  retryFilters(event) {
    event.preventDefault()
    this.applyServerFilters()
  }

  async loadDocuments(location, { restoreSearch = false } = {}) {
    this.filterRequest?.abort()
    const request = new AbortController()
    this.filterRequest = request
    const url = new URL(location, window.location.href)
    const keepFocus = restoreSearch && this.hasSearchTarget && document.activeElement === this.searchTarget
    const caret = keepFocus ? this.searchTarget.selectionStart : null
    this.filterErrorTarget?.classList.add("hidden")
    this.element.setAttribute("aria-busy", "true")

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin", signal: request.signal
      })
      if (!response.ok) throw new Error(`Document filters failed: ${response.status}`)
      const html = await response.text()
      if (request.signal.aborted) return
      const parsed = new DOMParser().parseFromString(html, "text/html")
      const updated = parsed.querySelector('section[data-section="documents"][data-controller~="supplier-documents"]')
      if (!updated) throw new Error("Document section missing from response")
      const visible = !this.element.hidden
      updated.hidden = !visible
      updated.classList.toggle("hidden", !visible)
      updated.setAttribute("aria-hidden", String(!visible))
      this.element.replaceWith(updated)
      window.history.replaceState(window.history.state, "", url)
      if (keepFocus) {
        const input = updated.querySelector('[data-supplier-documents-target="search"]')
        input?.focus()
        if (caret != null) input?.setSelectionRange(caret, caret)
      }
    } catch (error) {
      if (error.name === "AbortError") return
      if (this.hasFilterErrorTarget) this.filterErrorTarget.classList.remove("hidden")
      console.error(error)
    } finally {
      if (this.filterRequest === request) {
        this.element.removeAttribute("aria-busy")
        this.filterRequest = null
      }
    }
  }

  pickFiles() {
    if (this.hasUploadInputTarget) this.uploadInputTarget.click()
  }

  dragOver(event) {
    if (!this.hasUploadInputTarget) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
    this.dropzoneTarget.classList.add("border-emerald-500", "bg-emerald-50")
  }

  dragLeave(event) {
    if (this.dropzoneTarget.contains(event.relatedTarget)) return

    this.dropzoneTarget.classList.remove("border-emerald-500", "bg-emerald-50")
  }

  dropFiles(event) {
    if (!this.hasUploadInputTarget) return

    event.preventDefault()
    this.dragLeave(event)
    if (!event.dataTransfer?.files?.length) return

    try {
      this.uploadInputTarget.files = event.dataTransfer.files
      this.filesChanged()
    } catch (_error) {
      this.showUploadError()
    }
  }

  filesChanged() {
    this.closeQueuedPreview()
    this.revokeQueuedUrls()
    const files = Array.from(this.uploadInputTarget.files || [])
    this.queuedFiles = files.map((file) => ({ file, url: URL.createObjectURL(file) }))
    this.renderQueuedFiles()
    this.uploadSelectionTarget.classList.toggle("hidden", files.length === 0)
    this.uploadErrorTarget.classList.add("hidden")
    if (!files.length) {
      this.uploadSubmitTarget.disabled = true
      return
    }

    this.uploadCountTarget.textContent = this.filesSelectedValue.replace("%{count}", String(files.length))
    this.uploadNamesTarget.textContent = files.map((file) => file.name).join(" · ")
    const extensions = ["pdf", "png", "jpg", "jpeg", "doc", "docx", "xls", "xlsx", "csv", "xml", "txt"]
    const valid = files.length <= 10 && files.every((file) => (
      file.size > 0 && file.size <= 10 * 1024 * 1024 &&
      extensions.includes(file.name.split(".").pop().toLowerCase())
    ))
    this.uploadSubmitTarget.disabled = !valid
    this.uploadSubmitTarget.classList.toggle("opacity-40", !valid)
    if (!valid) this.showUploadError()
  }

  revokeQueuedUrls() {
    this.queuedFiles?.forEach(({ url }) => URL.revokeObjectURL(url))
    this.queuedFiles = []
  }

  renderQueuedFiles() {
    if (!this.hasQueuedListTarget) return
    this.queuedListTarget.replaceChildren()
    this.queuedFiles.forEach(({ file, url }, index) => {
      const tile = document.createElement("button")
      tile.type = "button"
      tile.dataset.queuedFile = String(index)
      tile.className = "flex min-w-0 items-center gap-3 rounded-xl border border-emerald-200 bg-white p-2 text-left text-sm transition hover:border-emerald-500 hover:bg-emerald-50 focus-visible:outline-2 focus-visible:outline-emerald-600"
      tile.setAttribute("aria-label", `${this.queuedListTarget.dataset.previewLabel}: ${file.name}`)
      const thumbnail = document.createElement("span")
      thumbnail.className = "flex size-12 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-emerald-50 text-xs font-bold text-emerald-800"
      if (file.type.startsWith("image/")) {
        const image = document.createElement("img")
        image.src = url
        image.alt = ""
        image.className = "size-full object-cover"
        thumbnail.append(image)
      } else {
        thumbnail.textContent = file.name.split(".").pop().toUpperCase().slice(0, 5)
      }
      const name = document.createElement("span")
      name.className = "min-w-0 flex-1 truncate text-xs font-semibold text-slate-700"
      name.textContent = file.name
      tile.append(thumbnail, name)
      tile.addEventListener("click", () => this.openQueuedPreview(index, tile))
      this.queuedListTarget.append(tile)
    })
  }

  openQueuedPreview(index, trigger) {
    if (!this.hasQueuedDialogTarget) return
    const item = this.queuedFiles[index]
    if (!item) return
    this.queuedPreviewTrigger = trigger
    this.queuedNameTarget.textContent = item.file.name
    this.queuedImageTarget.classList.add("hidden")
    this.queuedFrameTarget.classList.add("hidden")
    this.queuedTextTarget.classList.add("hidden")
    this.queuedUnsupportedTarget.classList.add("hidden")
    this.queuedImageTarget.removeAttribute("src")
    this.queuedFrameTarget.removeAttribute("src")
    if (item.file.type.startsWith("image/")) {
      this.queuedImageTarget.src = item.url
      this.queuedImageTarget.classList.remove("hidden")
    } else if (item.file.type === "application/pdf" || item.file.name.toLowerCase().endsWith(".pdf")) {
      this.queuedFrameTarget.src = item.url
      this.queuedFrameTarget.classList.remove("hidden")
    } else if (item.file.type === "text/plain") {
      this.queuedTextTarget.textContent = ""
      this.queuedTextTarget.classList.remove("hidden")
      item.file.text().then((content) => {
        if (!this.queuedDialogTarget.classList.contains("hidden") &&
          this.queuedPreviewTrigger === trigger) this.queuedTextTarget.textContent = content
      })
    } else {
      this.queuedUnsupportedTarget.classList.remove("hidden")
    }
    this.queuedDialogOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
    this.queuedDialogTarget.classList.remove("hidden")
    this.queuedDialogTarget.setAttribute("aria-hidden", "false")
    this.queuedCloseTarget.focus()
  }

  closeQueuedPreview({ restoreFocus = true } = {}) {
    if (!this.hasQueuedDialogTarget || this.queuedDialogTarget.classList.contains("hidden")) return
    this.queuedDialogTarget.classList.add("hidden")
    this.queuedDialogTarget.setAttribute("aria-hidden", "true")
    this.queuedFrameTarget.removeAttribute("src")
    this.queuedImageTarget.removeAttribute("src")
    document.body.style.overflow = this.queuedDialogOverflow || ""
    if (restoreFocus && this.queuedPreviewTrigger?.isConnected) this.queuedPreviewTrigger.focus()
    this.queuedPreviewTrigger = null
  }

  queuedKeydown(event) {
    if (!this.hasQueuedDialogTarget || this.queuedDialogTarget.classList.contains("hidden")) return
    if (event.key === "Escape") {
      event.preventDefault()
      this.closeQueuedPreview()
    } else if (event.key === "Tab") {
      // The dismiss control is the only action in the pending-file preview.
      event.preventDefault()
      this.queuedCloseTarget.focus()
    }
  }

  showUploadError() {
    this.uploadErrorTarget.textContent = this.invalidFilesValue
    this.uploadErrorTarget.classList.remove("hidden")
  }

  submitUploads(event) {
    if (this.uploadSubmitTarget.disabled || !this.uploadInputTarget.files.length) event.preventDefault()
  }

  previous() {
    if (this.hasPreviousUrlValue) return this.loadDocuments(this.previousUrlValue)
    if (this.hasServerPageValue || this.pageNumber <= 1) return
    this.pageNumber -= 1
    this.refresh()
  }

  next() {
    if (this.hasNextUrlValue) return this.loadDocuments(this.nextUrlValue)
    if (this.hasServerPageValue || this.pageNumber * this.pageSizeValue >= this.matches().length) return
    this.pageNumber += 1
    this.refresh()
  }

  select(event) {
    const card = event.currentTarget.closest("[data-document-id]")
    if (!card) return

    this.selectedId = card.dataset.documentId
    this.lastTrigger = event.currentTarget
    this.openPreview()
    this.renderSelection(card)
  }

  openPreview() {
    this.scrollWasLocked = document.body.classList.contains("overflow-hidden")
    document.body.classList.add("overflow-hidden")
    this.dialogTarget.classList.remove("hidden")
    this.closeButtonTarget.focus()
  }

  closePreview({ restoreFocus = true } = {}) {
    if (!this.hasDialogTarget || this.dialogTarget.classList.contains("hidden")) return

    this.dialogTarget.classList.add("hidden")
    this.cancelPreview()
    this.previewFrameTarget.removeAttribute("src")
    this.previewImageTarget.removeAttribute("src")
    if (!this.scrollWasLocked) document.body.classList.remove("overflow-hidden")
    if (restoreFocus && this.lastTrigger?.isConnected) this.lastTrigger.focus()
  }

  handleKeydown(event) {
    if (this.dialogTarget.classList.contains("hidden")) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.closePreview()
    } else if (event.key === "Tab") {
      this.keepFocusInsideDialog(event)
    }
  }

  keepFocusInsideDialog(event) {
    const all = this.dialogTarget.querySelectorAll(
      "button:not([disabled]), a[href], summary, input:not([disabled]), select:not([disabled]), textarea:not([disabled])"
    )
    const visible = Array.from(all).filter((element) => (
      element.getClientRects().length && !element.closest(".hidden")
    ))
    const first = visible[0]
    const last = visible[visible.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last?.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first?.focus()
    }
  }

  matches() {
    const term = this.searchTarget.value.trim().toLocaleLowerCase()
    const category = this.categorySelectTarget.value
    const state = this.statusTarget.value
    const days = Number(this.dateTarget.value)
    const cutoff = days ? new Date(Date.now() - days * 86400000) : null

    return this.cardTargets.filter((card) => (
      (!category || card.dataset.category === category) &&
      (!state || card.dataset.status === state) &&
      (!cutoff || new Date(card.dataset.uploaded) >= cutoff) &&
      (!term || [card.dataset.filename, card.dataset.description, card.dataset.category]
        .some((value) => (value || "").toLocaleLowerCase().includes(term)))
    ))
  }

  refresh() {
    const matches = this.matches()
    const total = matches.length
    const server = this.hasServerPageValue &&
      (this.serverTotalValue > this.pageSizeValue || this.serverFilteredValue)
    const localPages = Math.max(1, Math.ceil(total / this.pageSizeValue))
    if (!server) this.pageNumber = Math.min(this.pageNumber, localPages)
    const start = server ? 0 : (this.pageNumber - 1) * this.pageSizeValue
    const visible = matches.slice(start, start + this.pageSizeValue)

    this.cardTargets.forEach((card) => {
      const displayed = visible.includes(card)
      card.classList.toggle("hidden", !displayed)
      card.setAttribute("aria-hidden", String(!displayed))
    })
    this.noResultsTarget.classList.toggle("hidden", total > 0)
    const overall = server ? this.serverTotalValue : total
    const first = server ? (this.pageNumber - 1) * this.pageSizeValue + 1 : start + 1
    const last = server ? Math.min(this.pageNumber * this.pageSizeValue, overall) :
      Math.min(start + this.pageSizeValue, total)
    this.rangeTarget.textContent = this.rangeLabelValue
      .replace("%{from}", overall ? String(first) : "0")
      .replace("%{to}", String(last))
      .replace("%{total}", String(overall))
    this.pageTarget.textContent = String(this.pageNumber)
    const previousDisabled = server ? !this.hasPreviousUrlValue : this.pageNumber === 1
    const nextDisabled = server ? !this.hasNextUrlValue : this.pageNumber === localPages
    this.previousTarget.disabled = previousDisabled
    this.nextTarget.disabled = nextDisabled
    this.previousTarget.classList.toggle("opacity-40", previousDisabled)
    this.nextTarget.classList.toggle("opacity-40", nextDisabled)

    const selected = visible.find((card) => card.dataset.documentId === this.selectedId)
    if (selected) this.renderSelection(selected)
    else this.clearSelection()
  }

  clearSelection() {
    this.selectedId = null
    this.closePreview()
    this.cancelPreview()
    this.cardTargets.forEach((card) => this.markSelected(card, false))
    this.previewContentTarget.classList.add("hidden")
    this.previewEmptyTarget.classList.remove("hidden")
    this.previewFrameTarget.removeAttribute("src")
    this.previewImageTarget.removeAttribute("src")
    this.previewTextTarget.textContent = ""
  }

  markSelected(card, selected) {
    card.classList.toggle("border-emerald-500", selected)
    card.classList.toggle("bg-emerald-50/50", selected)
    card.classList.toggle("ring-1", selected)
    card.classList.toggle("ring-emerald-500", selected)
    const button = card.querySelector('[data-action="supplier-documents#select"]')
    if (button) button.setAttribute("aria-pressed", String(selected))
  }

  renderSelection(card) {
    const data = card.dataset
    this.cardTargets.forEach((item) => this.markSelected(item, item === card))
    this.selectedId = data.documentId
    this.previewEmptyTarget.classList.add("hidden")
    this.previewContentTarget.classList.remove("hidden")
    this.previewNameTarget.textContent = data.filename
    this.previewTypeTarget.textContent = data.categoryLabel || data.category
    this.previewSizeTarget.textContent = data.size
    this.previewDateTarget.textContent = data.date
    this.previewDescriptionTarget.textContent = data.description || "—"
    this.downloadTarget.href = data.downloadUrl
    this.openTarget.href = data.previewKind !== "none" ? data.previewUrl : data.downloadUrl
    this.renderPreview(data)
    this.syncEditForms(data)
  }

  renderPreview(data) {
    this.cancelPreview()
    this.previewFrameTarget.classList.add("hidden")
    this.previewImageTarget.classList.add("hidden")
    this.previewTextTarget.classList.add("hidden")
    this.unsupportedTarget.classList.add("hidden")
    this.previewErrorTarget.classList.add("hidden")
    this.previewFrameTarget.removeAttribute("src")
    this.previewImageTarget.removeAttribute("src")
    this.previewTextTarget.textContent = ""

    switch (data.previewKind) {
      case "pdf":
        this.previewFrameTarget.classList.remove("hidden")
        this.previewFrameTarget.src = data.previewUrl
        break
      case "image":
        this.previewImageTarget.classList.remove("hidden")
        this.previewImageTarget.src = data.previewUrl
        break
      case "text":
        this.loadTextPreview(data)
        break
      default:
        this.unsupportedTarget.classList.remove("hidden")
    }
  }

  async loadTextPreview(data) {
    const request = new AbortController()
    this.previewRequest = request
    try {
      const response = await fetch(data.previewUrl, {
        credentials: "same-origin",
        signal: request.signal,
        headers: { Accept: "text/plain" }
      })
      if (!response.ok) throw new Error("Preview request failed")
      const content = await response.text()
      if (request.signal.aborted || data.documentId !== this.selectedId) return

      this.previewTextTarget.textContent = content
      this.previewTextTarget.classList.remove("hidden")
    } catch (error) {
      if (request.signal.aborted || data.documentId !== this.selectedId) return
      this.previewErrorTarget.classList.remove("hidden")
    }
  }

  cancelPreview() {
    this.previewRequest?.abort()
    this.previewRequest = null
  }

  syncEditForms(data) {
    if (this.hasEditFormTarget) {
      this.editFormTarget.action = data.updateUrl
      this.editCategoryTarget.value = data.category
      this.editStatusTarget.value = data.status
      this.editDescriptionTarget.value = data.description
      this.editDetailsTarget.open = false
    }
    if (this.hasReplaceFormTarget) {
      this.replaceFormTarget.action = data.updateUrl
      this.replaceDetailsTarget.open = false
    }
  }
}
