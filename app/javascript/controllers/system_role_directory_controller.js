import { Controller } from "@hotwired/stimulus"

// Server-backed directory: filters and pagination remain ordinary Rails requests.
export default class extends Controller {
  static targets = ["filterForm"]

  openCreate() {
    const dialog = this.element.querySelector("#new-role-dialog")
    if (!dialog || dialog.open) return

    dialog.showModal()
    dialog.querySelector('[name="system_role[name]"]')?.focus()
  }

  submitFilters() {
    if (this.hasFilterFormTarget) this.filterFormTarget.requestSubmit()
  }
}
