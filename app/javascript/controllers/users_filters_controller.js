import { Controller } from "@hotwired/stimulus"

// Sync the directory URL with the applied filters. Keep the explicit Apply
// button for keyboard and non-JavaScript navigation.
export default class extends Controller {
  connect() {
    this.pendingSearch = null
    this.restoreSearchFocus()
  }

  disconnect() {
    clearTimeout(this.pendingSearch)
  }

  searchChanged(event) {
    if (event.target.name !== "q") return

    clearTimeout(this.pendingSearch)
    this.pendingSearch = setTimeout(() => this.submitFilters(), 450)
  }

  filterChanged(event) {
    if (!["user_type", "status", "role", "branch"].includes(event.target.name)) return

    clearTimeout(this.pendingSearch)
    this.submitFilters()
  }

  submitFilters() {
    if (!this.element.isConnected) return

    const search = this.element.querySelector("#users-filter-search")
    if (search && document.activeElement === search) {
      sessionStorage.setItem("delta-users-search-focus", JSON.stringify({
        path: window.location.pathname,
        start: search.selectionStart,
        end: search.selectionEnd
      }))
    }
    this.element.requestSubmit()
  }

  restoreSearchFocus() {
    const raw = sessionStorage.getItem("delta-users-search-focus")
    if (!raw) return

    sessionStorage.removeItem("delta-users-search-focus")
    try {
      const saved = JSON.parse(raw)
      if (saved.path !== window.location.pathname) return
      const search = this.element.querySelector("#users-filter-search")
      if (!search) return

      search.focus({ preventScroll: true })
      if (saved.start !== null && saved.end !== null) {
        search.setSelectionRange(saved.start, saved.end)
      }
    } catch (_error) {
      // Ignore stale focus state while keeping the filter form functional.
    }
  }
}
