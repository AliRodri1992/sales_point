import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.pending = null
    this.request = null
  }

  disconnect() {
    window.clearTimeout(this.pending)
    this.request?.abort()
  }

  schedule(event) {
    if (event.type === "input" && !event.target.matches("input[type=search], input[type=number]")) return
    if (event.type === "change" && event.target.matches("input[type=search], input[type=number]")) return

    window.clearTimeout(this.pending)
    const delay = event.target.matches("input[type=search], input[type=number]") ? 400 : 100
    this.pending = window.setTimeout(() => this.refresh(), delay)
  }

  submit(event) {
    event.preventDefault()
    window.clearTimeout(this.pending)
    this.refresh()
  }

  async refresh() {
    this.request?.abort()
    this.request = new AbortController()
    const url = new URL(this.element.action)
    const params = new URLSearchParams(new FormData(this.element))
    params.delete("page")
    url.search = params.toString()

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
        credentials: "same-origin",
        signal: this.request.signal
      })
      if (!response.ok) throw new Error(`Supplier filtering failed: ${response.status}`)
      const html = await response.text()
      if (this.request.signal.aborted) return
      window.Turbo.renderStreamMessage(html)
      window.history.replaceState(window.history.state, "", url)
    } catch (error) {
      if (error.name !== "AbortError") console.error(error)
    }
  }
}
