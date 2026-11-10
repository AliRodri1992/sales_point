import { Controller } from "@hotwired/stimulus"

// Keep filter controls aligned with results refreshed by Turbo Frames or Streams.
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
      const select = this.element.querySelector("#" + id)
      if (!select || !value || select.value === value) return
      if (![...select.options].some((option) => option.value === value)) return

      select.value = value
      select.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }

  disconnect() {
    clearTimeout(this.timeoutId)
    document.removeEventListener("turbo:frame-load", this.onFrameLoad)
    this.resultsObserver?.disconnect()
  }
}
