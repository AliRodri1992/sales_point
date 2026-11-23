import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "status", "selection"]
  static values = { kind: String, key: String, url: String, empty: String, loading: String, error: String, found: String }

  disconnect() {
    this.cancel()
  }

  cancel() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  clear() {
    this.cancel()
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = true
    this.queryTarget.setAttribute("aria-expanded", "false")
    this.resultsTarget.removeAttribute("aria-busy")
    this.statusTarget.textContent = ""
  }

  queue() {
    this.clear()
    if (this.hasSelectionTarget) this.selectionTarget.value = ""
    const query = this.queryTarget.value.trim()
    if (!query) return
    this.statusTarget.textContent = this.loadingValue
    this.resultsTarget.setAttribute("aria-busy", "true")
    this.timer = setTimeout(() => this.search(query), 200)
  }

  async search(query) {
    const request = new AbortController()
    this.request = request
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, { signal: request.signal, headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error()
      const items = (await response.json())[this.keyValue]
      if (request.signal.aborted) return
      this.resultsTarget.replaceChildren(...items.map((item) => this.result(item)))
      this.resultsTarget.hidden = !items.length
      this.queryTarget.setAttribute("aria-expanded", String(items.length > 0))
      this.statusTarget.textContent = items.length ? this.foundValue.replace("__COUNT__", items.length) : this.emptyValue
    } catch {
      if (!request.signal.aborted) this.statusTarget.textContent = this.errorValue
    } finally {
      if (!request.signal.aborted) this.resultsTarget.removeAttribute("aria-busy")
    }
  }

  result(item) {
    const li = document.createElement("li")
    li.setAttribute("role", "presentation")
    const button = document.createElement("button")
    button.type = "button"
    button.setAttribute("role", "option")
    button.setAttribute("aria-selected", "false")
    button.className = "block min-h-11 w-full px-3 py-2 text-left text-sm hover:bg-emerald-50 focus:bg-emerald-50"
    button.textContent = [item.name, item.sku || item.code].filter(Boolean).join(" · ")
    button.addEventListener("click", () => this.choose(item))
    li.append(button)
    return li
  }

  choose(item) {
    this.clear()
    if (this.hasSelectionTarget) {
      this.selectionTarget.value = item.id
      this.queryTarget.value = item.name
      this.selectionTarget.dispatchEvent(new Event("change", { bubbles: true }))
    } else {
      this.dispatch("pick", { detail: { kind: this.kindValue, id: String(item.id), name: item.name } })
      this.queryTarget.value = ""
    }
    this.queryTarget.focus()
  }

  first(event) {
    if (this.resultsTarget.hidden) return
    event.preventDefault()
    this.resultsTarget.querySelector("button")?.focus()
  }

  next(event) {
    event.preventDefault()
    event.target.closest("li")?.nextElementSibling?.querySelector("button")?.focus()
  }

  previous(event) {
    event.preventDefault()
    const previous = event.target.closest("li")?.previousElementSibling?.querySelector("button")
    const target = previous || this.queryTarget
    target.focus()
  }

  close(event) {
    event.preventDefault()
    this.clear()
    this.queryTarget.focus()
  }
}
