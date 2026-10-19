import { Controller } from "@hotwired/stimulus"

// Read-only document library controls; mutations use authenticated Rails forms.
export default class extends Controller {
  static targets = [
    "category", "search", "format", "status", "date", "card", "noResults",
    "range", "page", "previous", "next", "previewContent", "previewEmpty",
    "previewName", "previewType", "previewSize", "previewDate", "previewDescription",
    "previewFrame", "previewImage", "unsupported", "download", "open",
    "replaceForm", "editForm", "editCategory", "editStatus", "editDescription",
    "replaceDetails", "editDetails"
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
    this.refresh()
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
    this.renderSelection(card)
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
    })

    const selection = visible.find((card) => card.dataset.documentId === this.selectedId) || visible[0]
    if (selection) {
      this.selectedId = selection.dataset.documentId
      this.renderSelection(selection)
    } else {
      this.selectedId = null
      this.previewEmptyTarget.classList.remove("hidden")
      this.previewContentTarget.classList.add("hidden")
      this.previewFrameTarget.removeAttribute("src")
    }
  }

  renderSelection(card) {
    this.cardTargets.forEach((item) => {
      const selected = item === card
      item.classList.toggle("border-emerald-500", selected)
      item.classList.toggle("bg-emerald-50/50", selected)
    })

    const data = card.dataset
    this.previewEmptyTarget.classList.add("hidden")
    this.previewContentTarget.classList.remove("hidden")
    this.previewNameTarget.textContent = data.filename
    const category = this.categoryTargets.find((item) => item.dataset.category === data.category)
    this.previewTypeTarget.textContent = category?.firstChild?.textContent?.trim() || data.category
    this.previewSizeTarget.textContent = data.size
    this.previewDateTarget.textContent = data.date
    this.previewDescriptionTarget.textContent = data.description || "—"
    this.downloadTarget.href = data.downloadUrl
    this.openTarget.href = data.previewable === "true" ? data.previewUrl : data.downloadUrl

    const pdf = data.previewable === "true" && data.format === "pdf"
    const image = data.previewable === "true" && ["png", "jpg", "jpeg"].includes(data.format)
    this.previewFrameTarget.classList.toggle("hidden", !pdf)
    this.previewImageTarget.classList.toggle("hidden", !image)
    this.unsupportedTarget.classList.toggle("hidden", pdf || image)
    if (pdf) {
      if (this.previewFrameTarget.getAttribute("src") !== data.previewUrl) this.previewFrameTarget.src = data.previewUrl
    } else {
      this.previewFrameTarget.removeAttribute("src")
    }
    if (image) this.previewImageTarget.src = data.previewUrl
    else this.previewImageTarget.removeAttribute("src")

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
