import { Controller } from "@hotwired/stimulus"

// Preserve header sorting when the search or status form refreshes Turbo results.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.timeoutId = null
    this.onFrameLoad = (event) => {
      if (event.target.id === "categories_list") this.syncSorting(event.target)
    }
    document.addEventListener("turbo:frame-load", this.onFrameLoad)

    const results = document.getElementById("categories_list")
    if (results) {
      this.resultsObserver = new MutationObserver(() => this.syncSorting(results))
      this.resultsObserver.observe(results, { childList: true, subtree: true })
    }
  }

  debouncedSubmit() {
    clearTimeout(this.timeoutId)
    this.timeoutId = setTimeout(() => this.submitNow(), this.delayValue)
  }

  submitNow() {
    clearTimeout(this.timeoutId)
    this.element.requestSubmit()
  }

  syncSorting(frame) {
    const directory = frame?.querySelector(".categories-directory")
    if (!directory) return

    const state = {
      category_sort: directory.dataset.categoriesCurrentSort,
      category_direction: directory.dataset.categoriesCurrentDirection
    }

    Object.entries(state).forEach(([id, value]) => {
      const input = this.element.querySelector("#" + id)
      if (input && value && input.value !== value) input.value = value
    })
  }

  disconnect() {
    clearTimeout(this.timeoutId)
    document.removeEventListener("turbo:frame-load", this.onFrameLoad)
    this.resultsObserver?.disconnect()
  }
}
