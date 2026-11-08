import { Controller } from "@hotwired/stimulus"

// Sync the directory URL with the applied filters. Keep the explicit Apply
// button for keyboard and non-JavaScript navigation.
export default class extends Controller {
  connect() {
    this.pendingSearch = null
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
    if (!["user_type", "status", "role"].includes(event.target.name)) return

    clearTimeout(this.pendingSearch)
    this.submitFilters()
  }

  submitFilters() {
    if (this.element.isConnected) this.element.requestSubmit()
  }
}
