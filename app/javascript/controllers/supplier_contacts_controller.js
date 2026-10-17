import { Controller } from "@hotwired/stimulus"

// Loads one server-rendered page at a time inside the supplier's contact list.
// Search and filters run on the server; no duplicate full-list download is needed.
export default class extends Controller {
  static targets = ["scroll", "list", "search", "filter", "filterCount", "count", "sentinel", "empty", "loading", "error", "loadMore"]
  static values = {
    url: String,
    nextPage: Number,
    filter: { type: String, default: "all" }
  }

  connect() {
    this.loading = false
    this.queryPending = false
    this.request = null
    this.searchTimer = null
    this.updateLoadMore()

    if (this.hasScrollTarget && this.hasSentinelTarget && "IntersectionObserver" in window) {
      this.observer = new IntersectionObserver((entries) => {
        if (entries.some((entry) => entry.isIntersecting)) this.loadMore()
      }, { root: this.scrollTarget, rootMargin: "200px 0px" })
      this.observer.observe(this.sentinelTarget)
    }
  }

  disconnect() {
    clearTimeout(this.searchTimer)
    this.observer?.disconnect()
    this.abortRequest()
  }

  toggleCard(event) {
    const button = event.currentTarget
    const details = document.getElementById(button.getAttribute("aria-controls"))
    if (!details || !this.element.contains(details)) return

    const expanded = button.getAttribute("aria-expanded") !== "true"
    button.setAttribute("aria-expanded", String(expanded))
    button.setAttribute("aria-label", expanded ? button.dataset.collapseLabel : button.dataset.expandLabel)
    details.classList.toggle("hidden", !expanded)
    button.querySelector("svg")?.classList.toggle("rotate-180", expanded)
  }

  search() {
    clearTimeout(this.searchTimer)
    this.queryPending = true
    this.abortRequest()
    this.searchTimer = setTimeout(() => {
      this.queryPending = false
      this.refresh()
    }, 250)
  }

  applyFilter(event) {
    const nextFilter = event.currentTarget.dataset.filter
    if (this.filterValue === nextFilter) return

    clearTimeout(this.searchTimer)
    this.queryPending = false
    this.filterValue = nextFilter
    this.filterTargets.forEach((button) => {
      const active = button.dataset.filter === nextFilter
      button.setAttribute("aria-pressed", String(active))
      button.classList.toggle("bg-emerald-100", active)
      button.classList.toggle("text-emerald-800", active)
      button.classList.toggle("bg-slate-100", !active)
      button.classList.toggle("text-slate-600", !active)
      button.classList.toggle("hover:bg-slate-200", !active)
    })
    this.refresh()
  }

  refresh() {
    this.abortRequest()
    this.listTarget.replaceChildren()
    this.nextPageValue = 1
    this.countTarget.textContent = "0"
    this.emptyTarget.classList.add("hidden")
    this.errorTarget.classList.add("hidden")
    this.scrollTarget.scrollTop = 0
    this.loadMore()
  }

  abortRequest() {
    this.request?.abort()
    this.request = null
    this.loading = false
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
  }

  updateLoadMore() {
    if (this.hasLoadMoreTarget) {
      this.loadMoreTarget.classList.toggle("hidden", !this.nextPageValue || this.loading)
    }
  }

  async loadMore(event) {
    event?.preventDefault()
    if (this.loading || this.queryPending || !this.nextPageValue) return

    const controller = new AbortController()
    this.request = controller
    this.loading = true
    this.updateLoadMore()
    this.loadingTarget.classList.remove("hidden")
    this.errorTarget.classList.add("hidden")

    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("page", String(this.nextPageValue))
    url.searchParams.set("filter", this.filterValue)
    const query = this.searchTarget.value.trim()
    if (query) url.searchParams.set("q", query)

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin",
        signal: controller.signal
      })
      if (!response.ok) throw new Error(`Contact request failed: ${response.status}`)

      const markup = await response.text()
      if (this.request !== controller) return

      this.listTarget.insertAdjacentHTML("beforeend", markup)
      this.nextPageValue = Number(response.headers.get("X-Next-Page")) || 0
      const total = Number(response.headers.get("X-Contacts-Count")) || 0
      this.countTarget.textContent = String(total)
      const counts = JSON.parse(response.headers.get("X-Contacts-Filter-Counts") || "{}")
      this.filterCountTargets.forEach((badge) => {
        badge.textContent = String(counts[badge.dataset.filter] ?? 0)
      })
      this.emptyTarget.classList.toggle("hidden", total > 0)
    } catch (error) {
      if (error.name !== "AbortError" && this.request === controller) {
        this.errorTarget.classList.remove("hidden")
      }
    } finally {
      if (this.request === controller) {
        this.loading = false
        this.request = null
        this.loadingTarget.classList.add("hidden")
        this.updateLoadMore()
      }
    }
  }
}
