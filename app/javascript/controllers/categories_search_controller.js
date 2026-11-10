import { Controller } from "@hotwired/stimulus"

// Search remains responsive while the catalog is refreshed through Turbo Frames.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.timeoutId = null
    this.onFrameLoad = (event) => this.syncSorting(event)
    document.addEventListener("turbo:frame-load", this.onFrameLoad)
  }

  debouncedSubmit() {
    clearTimeout(this.timeoutId)
    this.timeoutId = setTimeout(() => this.submitNow(), this.delayValue)
  }

  submitNow() {
    clearTimeout(this.timeoutId)
    this.element.requestSubmit()
  }

  syncSorting(event) {
    if (event.target.id !== "categories_list") return

    const directory = event.target.querySelector(".categories-directory")
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
  }
}
