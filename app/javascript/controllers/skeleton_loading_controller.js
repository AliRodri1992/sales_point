import { Controller } from "@hotwired/stimulus"

// Scoped loading state: preserve existing records during refreshes, and only
// display the skeleton when there is no usable content yet.
export default class extends Controller {
  static targets = ["content", "placeholder", "status"]
  static values = {
    region: String,
    delay: { type: Number, default: 140 }
  }

  connect() {
    this.activeRequestId = null
    this.loading = false
  }

  disconnect() {
    this.clear()
  }

  begin(event) {
    if (event.detail?.region !== this.regionValue) return

    this.cancelPending()
    this.loading = true
    this.activeRequestId = event.detail.requestId ?? null
    this.element.setAttribute("aria-busy", "true")
    if (this.hasStatusTarget) this.statusTarget.hidden = false

    if (!this.hasContentTarget || !this.hasPlaceholderTarget) return
    const hasRecords = this.contentTarget.querySelector(
      "tbody tr, [data-supplier-mobile-card], [data-skeleton-record]"
    )
    if (hasRecords) return

    this.showTimer = window.setTimeout(() => {
      if (!this.loading) return
      this.contentTarget.hidden = true
      this.placeholderTarget.hidden = false
    }, this.delayValue)
  }

  finish(event) {
    if (event?.detail?.region && event.detail.region !== this.regionValue) return
    if (event?.detail?.requestId != null &&
        event.detail.requestId !== this.activeRequestId) return
    this.clear()
  }

  clear() {
    this.cancelPending()
    this.loading = false
    this.activeRequestId = null
    this.element.setAttribute("aria-busy", "false")
    if (this.hasStatusTarget) this.statusTarget.hidden = true
    if (this.hasContentTarget) this.contentTarget.hidden = false
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = true
  }

  cancelPending() {
    window.clearTimeout(this.showTimer)
  }

  related(target) {
    const frame = target?.closest?.("turbo-frame")
    const formFrame = target?.dataset?.turboFrame ||
      target?.closest?.("form[data-turbo-frame]")?.dataset?.turboFrame
    return frame?.id === this.regionValue || formFrame === this.regionValue ||
      target?.id === this.regionValue
  }

  turboStart(event) {
    if (this.related(event.target)) this.begin({ detail: { region: this.regionValue } })
  }

  turboFinish(event) {
    if (event.target?.id === this.regionValue) this.clear()
  }

  turboError(event) {
    if (this.related(event.target)) this.clear()
  }
}
