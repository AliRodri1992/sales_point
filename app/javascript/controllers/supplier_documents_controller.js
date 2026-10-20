import { Controller } from "@hotwired/stimulus"

// Browses supplier attachments locally; every preview uses the authorized Rails endpoint.
export default class extends Controller {
  static targets = [
    "category", "search", "format", "status", "date", "card", "noResults",
    "range", "page", "previous", "next", "previewContent", "previewEmpty",
    "previewName", "previewType", "previewSize", "previewDate", "previewDescription",
    "previewFrame", "previewImage", "previewText", "unsupported", "previewError",
    "dialog", "closeButton",
    "download", "open", "replaceForm", "editForm", "editCategory", "editStatus",
    "editDescription", "replaceDetails", "editDetails"
  ]

  static values = {
    rangeLabel: String,
    pageSize: { type: Number, default: 8 }
  }

  connect() {
    if (!this.hasCardTarget) return

    this.category = "all"
    this.pageNumber = 1
    this.selectedId = null
    this.previewRequest = null
    this.lastTrigger = null
    this.scrollWasLocked = false
    this.refresh()
  }

  disconnect() {
    this.closePreview({ restoreFocus: false })
    this.cancelPreview()
  }

  filter(event) {
    if (event?.currentTarget?.dataset.category) {
      this.category = event.currentTarget.dataset.category
    }

    this.pageNumber = 1
    this.refresh()
  }

  previous() {
    if (this.pageNumber <= 1) return
    this.pageNumber -= 1
    this.refresh()
  }

  next() {
    if (this.pageNumber * this.pageSizeValue >= this.matches().length) return
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
    const extension = this.formatTarget.value
    const state = this.statusTarget.value
    const days = Number(this.dateTarget.value)
    const cutoff = days ? new Date(Date.now() - days * 86400000) : null

    return this.cardTargets.filter((card) => (
      (this.category === "all" || card.dataset.category === this.category) &&
      (!extension || card.dataset.format === extension) &&
      (!state || card.dataset.status === state) &&
      (!cutoff || new Date(card.dataset.uploaded) >= cutoff) &&
      (!term || [card.dataset.filename, card.dataset.description, card.dataset.category]
        .some((value) => (value || "").toLocaleLowerCase().includes(term)))
    ))
  }

  refresh() {
    const matches = this.matches()
    const total = matches.length
    const pages = Math.max(1, Math.ceil(total / this.pageSizeValue))
    this.pageNumber = Math.min(this.pageNumber, pages)
    const start = (this.pageNumber - 1) * this.pageSizeValue
    const visible = matches.slice(start, start + this.pageSizeValue)

    this.cardTargets.forEach((card) => {
      const displayed = visible.includes(card)
      card.classList.toggle("hidden", !displayed)
      card.setAttribute("aria-hidden", String(!displayed))
    })
    this.noResultsTarget.classList.toggle("hidden", total > 0)
    this.rangeTarget.textContent = this.rangeLabelValue
      .replace("%{from}", total ? String(start + 1) : "0")
      .replace("%{to}", String(Math.min(start + this.pageSizeValue, total)))
      .replace("%{total}", String(total))
    this.pageTarget.textContent = String(this.pageNumber)
    this.previousTarget.disabled = this.pageNumber === 1
    this.nextTarget.disabled = this.pageNumber === pages
    this.previousTarget.classList.toggle("opacity-40", this.pageNumber === 1)
    this.nextTarget.classList.toggle("opacity-40", this.pageNumber === pages)

    this.categoryTargets.forEach((button) => {
      const active = button.dataset.category === this.category
      button.setAttribute("aria-pressed", String(active))
      button.classList.toggle("bg-emerald-700", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("border-emerald-700", active)
      button.classList.toggle("bg-white", !active)
      const count = button.querySelector("[data-category-count]")
      if (count) count.classList.toggle("text-emerald-800", active)
    })

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
    const category = this.categoryTargets.find((item) => item.dataset.category === data.category)
    this.previewTypeTarget.textContent = category?.firstChild?.textContent?.trim() || data.category
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
