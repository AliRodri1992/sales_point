import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Search results update without replacing the focused input. Explicit Apply,
// sorting and pagination still navigate normally so the URL remains shareable.
export default class extends Controller {
  static targets = ["error"]
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.composing = false
    this.sequence = 0
  }

  compositionStart() {
    this.composing = true
    clearTimeout(this.timeoutId)
  }

  compositionEnd() {
    this.composing = false
    this.debouncedSubmit()
  }

  debouncedSubmit() {
    if (this.composing) return
    clearTimeout(this.timeoutId)
    this.timeoutId = setTimeout(() => this.search(), this.delayValue)
  }

  cancelSearch() {
    clearTimeout(this.timeoutId)
    this.request?.abort()
  }

  disconnect() {
    this.cancelSearch()
  }

  searchUrl() {
    const url = new URL(this.element.action, window.location.href)
    for (const [key, value] of new FormData(this.element)) {
      const text = String(value).trim()
      const unselected = ["status", "featured", "tracking_mode", "stock_status"].includes(key) && text === "all"
      if (text && !unselected) url.searchParams.set(key, text)
      else url.searchParams.delete(key)
    }
    url.searchParams.delete("page")
    return url
  }

  async search() {
    this.request?.abort()
    const request = new AbortController()
    const sequence = ++this.sequence
    this.request = request
    const url = this.searchUrl()
    if (this.hasErrorTarget) this.errorTarget.hidden = true
    this.element.setAttribute("aria-busy", "true")

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html" },
        credentials: "same-origin",
        signal: request.signal
      })
      if (response.redirected) { Turbo.visit(response.url); return }
      if (!response.ok || !response.headers.get("content-type")?.includes("text/html")) throw new Error("search")

      const page = new DOMParser().parseFromString(await response.text(), "text/html")
      const nextResults = page.querySelector("#admin_products_list")
      const currentResults = document.querySelector("#admin_products_list")
      if (!nextResults || !currentResults) throw new Error("missing results")
      if (request.signal.aborted || sequence !== this.sequence) return

      // Keep the Turbo Frame element connected; replacing it outright breaks
      // the frame's navigation lifecycle and the surrounding loading state.
      currentResults.replaceChildren(...nextResults.childNodes)
      this.syncBadges(page)
      window.history.replaceState(window.history.state, "", url)
    } catch (error) {
      if (error.name !== "AbortError" && sequence === this.sequence && this.hasErrorTarget) {
        this.errorTarget.hidden = false
      }
    } finally {
      if (sequence === this.sequence) this.element.removeAttribute("aria-busy")
    }
  }

  syncBadges(page) {
    const panel = this.element.closest(".products-filter-panel")
    if (!panel) return
    panel.querySelector(".products-filter-chips")?.remove()
    const badges = page.querySelector(".products-filter-chips")
    if (badges) panel.append(badges)

    panel.querySelector(".products-filters__count")?.remove()
    const count = page.querySelector(".products-filters__count")
    const heading = panel.querySelector(".products-filter-panel__heading")
    if (count && heading) heading.append(count)
  }
}
