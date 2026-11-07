import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["form", "error"]

  connect() {
    this.sequence = 0
    this.composing = false
    this.element.setAttribute("aria-busy", "false")
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  compositionStart() { this.composing = true }
  compositionEnd() { this.composing = false; this.schedule() }

  schedule() {
    if (this.composing) return
    clearTimeout(this.timer)
    this.request?.abort()
    this.timer = setTimeout(() => this.apply(), 350)
  }

  change(event) {
    const name = event.target.name
    if (name === "country_id") {
      this.resetField("state")
      this.resetField("city")
    } else if (name === "state") this.resetField("city")
    this.apply(undefined, ["country_id", "state"].includes(name))
  }

  submit(event) {
    event.preventDefault()
    this.apply()
  }

  field(name) { return this.formTarget.elements.namedItem(name) }

  resetField(name, value = "") {
    const field = this.field(name)
    if (!field) return
    field.value = value
    const wrapper = field.closest('[data-controller~="delta-select"]')
    if (wrapper) this.application.getControllerForElementAndIdentifier(wrapper, "delta-select")?.refresh()
  }

  apply(event, locations = false) {
    event?.preventDefault()
    clearTimeout(this.timer)
    const url = new URL(window.location.href)
    url.pathname = new URL(this.formTarget.action).pathname
    for (const [key, value] of new FormData(this.formTarget)) {
      if (String(value).trim()) url.searchParams.set(key, String(value).trim())
      else url.searchParams.delete(key)
    }
    url.searchParams.delete("page")
    this.fetchResults(url, { locations })
  }

  remove(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.filterKey
    const field = this.field(key)
    if (!field) return
    this.resetField(key)
    this.apply(undefined, ["country_id", "state"].includes(key))
    this.field("search").focus()
  }

  clear(event) {
    event.preventDefault()
    for (const field of this.formTarget.elements) {
      if (field.name) this.resetField(field.name)
    }
    this.apply(undefined, true)
    this.field("search").focus()
  }

  navigate(event) {
    const link = event.target.closest("#branches_list th a, #branches_list nav a")
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    clearTimeout(this.timer)
    this.request?.abort()
    ++this.sequence
    this.element.setAttribute("aria-busy", "false")
    this.navigating = true
    Turbo.visit(link.href, { frame: "branches_list", action: "advance" })
  }

  navigated(event) {
    if (event.target.id !== "branches_list" || !this.navigating) return
    this.navigating = false
    this.element.querySelector("#branches-result-title")?.focus({ preventScroll: true })
  }

  restore() {
    const url = new URL(window.location.href)
    if (url.pathname !== new URL(this.formTarget.action).pathname) return
    for (const field of this.formTarget.elements) {
      if (field.name) this.resetField(field.name, url.searchParams.get(field.name) || "")
    }
    this.fetchResults(url, { history: false, locations: true })
  }

  retry(event) { event.preventDefault(); this.fetchResults(this.lastUrl, this.lastOptions) }

  async fetchResults(url, options = {}) {
    this.lastUrl = url
    this.lastOptions = options
    this.request?.abort()
    const request = new AbortController()
    this.request = request
    const sequence = ++this.sequence
    this.errorTarget.hidden = true
    this.element.setAttribute("aria-busy", "true")
    try {
      const response = await fetch(url, {
        headers: { Accept: "text/vnd.turbo-stream.html", "X-Branch-Locations": options.locations ? "1" : "0" },
        credentials: "same-origin", signal: request.signal
      })
      if (response.redirected) { Turbo.visit(response.url); return }
      if (!response.ok || !response.headers.get("content-type")?.includes("turbo-stream")) throw new Error("Branch filtering failed")
      const html = await response.text()
      if (request.signal.aborted || sequence !== this.sequence) return
      Turbo.renderStreamMessage(html)
      if (options.history !== false) window.history[options.history === "push" ? "pushState" : "replaceState"](window.history.state, "", url)
      if (options.focus) requestAnimationFrame(() => this.element.querySelector("#branches-result-title")?.focus({ preventScroll: true }))
    } catch (error) {
      if (error.name !== "AbortError" && sequence === this.sequence) this.errorTarget.hidden = false
    } finally {
      if (sequence === this.sequence) this.element.setAttribute("aria-busy", "false")
    }
  }
}
