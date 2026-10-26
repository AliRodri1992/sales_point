import { Controller } from "@hotwired/stimulus"

// The navigation is permission-aware; users may not have an Overview section.
export default class extends Controller {
  static targets = ["tab", "panel", "mobileSelect"]
  static values = { initialTab: { type: String, default: "overview" } }

  connect() {
    this.onPopState = () => this.activateTab(this.requestedTab(), false)
    this.activateTab(this.requestedTab(), false)
    window.addEventListener("popstate", this.onPopState)
  }

  disconnect() {
    window.removeEventListener("popstate", this.onPopState)
  }

  requestedTab() {
    const section = new URL(window.location.href).searchParams.get("tab") || this.initialTabValue
    return section === "finances" ? "statement" : section
  }

  select(event) {
    this.activateTab(event.currentTarget.dataset.section || event.currentTarget.value)
  }

  navigate(event) {
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const tabs = this.tabTargets
    const current = tabs.indexOf(event.currentTarget)
    const nextIndex = event.key === "Home" ? 0 : event.key === "End" ? tabs.length - 1 :
      (current + (event.key === "ArrowDown" ? 1 : -1) + tabs.length) % tabs.length
    const next = tabs[nextIndex]
    if (!next) return
    this.activateTab(next.dataset.section)
    next.focus()
  }

  activateTab(section, updateUrl = true) {
    const available = this.panelTargets.map((panel) => panel.dataset.section)
    // Never fall back to an inaccessible/absent Overview panel.
    const selected = available.includes(section) ? section : available[0]
    if (!selected) return

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.section === selected
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
      tab.classList.toggle("border-emerald-700", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("bg-emerald-50", active)
      tab.classList.toggle("text-emerald-800", active)
      tab.classList.toggle("font-semibold", active)
      tab.classList.toggle("text-slate-600", !active)
      tab.classList.toggle("font-medium", !active)
    })

    if (this.hasMobileSelectTarget) this.mobileSelectTarget.value = selected
    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.section === selected
      panel.hidden = !active
      panel.classList.toggle("hidden", !active)
      panel.setAttribute("aria-hidden", String(!active))
    })

    if (updateUrl) {
      const url = new URL(window.location.href)
      if (selected === "overview") url.searchParams.delete("tab")
      else url.searchParams.set("tab", selected)
      if (url.toString() !== window.location.href) {
        window.history.pushState(window.history.state, "", url)
      }
    }
  }
}
