import { Controller } from "@hotwired/stimulus"

// Keep the visible filters, shareable URL, and CRUD action URLs in sync with Turbo.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.timeoutId = null
    this.onFrameLoad = (event) => {
      if (event.target.id === "categories_list") this.syncResults(event.target)
    }
    this.onNavigationClick = (event) => {
      const link = event.target.closest("a[data-categories-filter-navigation]")
      if (link) this.applyFiltersToUrl(link, "href")
    }
    this.onMutationSubmit = (event) => {
      const form = event.target
      if (form.matches("form[data-categories-filter-mutation]")) this.applyFiltersToUrl(form, "action")
    }
    document.addEventListener("turbo:frame-load", this.onFrameLoad)
    document.addEventListener("click", this.onNavigationClick, true)
    document.addEventListener("submit", this.onMutationSubmit, true)

    const results = document.getElementById("categories_list")
    if (results) {
      this.resultsObserver = new MutationObserver(() => this.syncResults(results))
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

  changeSort(event) {
    if (this.syncingSort) return

    const [sort, direction] = event.target.value.split(":")
    if (!["name", "code", "status", "created_at", "updated_at"].includes(sort)) return
    if (!["asc", "desc"].includes(direction)) return

    this.element.querySelector("#category_sort").value = sort
    this.element.querySelector("#category_direction").value = direction
    this.submitNow()
  }

  filterEntries() {
    const data = new FormData(this.element)
    const state = {}
    for (const key of ["search", "status", "sort", "direction"]) {
      const value = String(data.get(key) || "")
      state[key] = value
    }
    return state
  }

  filteredUrl(originalUrl) {
    const url = new URL(originalUrl, window.location.href)
    const filters = this.filterEntries()
    for (const [key, value] of Object.entries(filters)) {
      if (!value || (key === "status" && value === "all")) {
        url.searchParams.delete(key)
      } else {
        url.searchParams.set(key, value)
      }
    }
    return url
  }

  applyFiltersToUrl(node, attribute) {
    const url = this.filteredUrl(node[attribute])
    node[attribute] = url.toString()
  }

  syncResults(frame) {
    const directory = frame.querySelector(".categories-directory")
    if (!directory) return

    const state = {
      category_sort: directory.dataset.categoriesCurrentSort,
      category_direction: directory.dataset.categoriesCurrentDirection
    }
    for (const [id, value] of Object.entries(state)) {
      const input = this.element.querySelector("#" + id)
      if (input && value && input.value !== value) input.value = value
    }

    const mobileSort = this.element.querySelector("#category_mobile_sort")
    const sortValue = `${state.category_sort}:${state.category_direction}`
    if (mobileSort && mobileSort.value !== sortValue &&
        [...mobileSort.options].some((option) => option.value === sortValue)) {
      this.syncingSort = true
      mobileSort.value = sortValue
      mobileSort.dispatchEvent(new Event("change", { bubbles: true }))
      this.syncingSort = false
    }

    // Turbo Frame pagination and filtering must share the actual page with the address bar.
    // A filter submission resets to page 1; explicit pagination keeps its requested page.
    const url = this.filteredUrl(window.location.href)
    const page = Number(directory.dataset.categoriesCurrentPage)
    if (Number.isInteger(page) && page >= 1) {
      if (page === 1) url.searchParams.delete("page")
      else url.searchParams.set("page", String(page))
    }
    if (url.href !== window.location.href) {
      window.history.replaceState(window.history.state, "", url.pathname + url.search + url.hash)
    }
  }

  disconnect() {
    clearTimeout(this.timeoutId)
    document.removeEventListener("turbo:frame-load", this.onFrameLoad)
    document.removeEventListener("click", this.onNavigationClick, true)
    document.removeEventListener("submit", this.onMutationSubmit, true)
    this.resultsObserver?.disconnect()
  }
}
