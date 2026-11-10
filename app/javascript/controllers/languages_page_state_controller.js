import { Controller } from "@hotwired/stimulus"

// Keep the address bar in sync when a deletion removes the last row on a page.
// The Turbo Stream updates the list, so replacing the URL must not reload it.
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (!this.hasUrlValue) return

    const canonical = new URL(this.urlValue, window.location.origin)
    if (canonical.origin !== window.location.origin || canonical.pathname !== window.location.pathname) return
    if (canonical.href === window.location.href) return

    window.history.replaceState(window.history.state, "", canonical.href)
  }
}
