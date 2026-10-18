import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "mobileSelect"]
  static values = { initialTab: { type: String, default: "overview" } }

  connect() {
    const requested = new URL(window.location.href).searchParams.get("tab") || this.initialTabValue
    this.activateTab(requested === "finances" ? "statement" : requested, false)
    this.onPopState = () => {
      const section = new URL(window.location.href).searchParams.get("tab") || "overview"
      this.activateTab(section === "finances" ? "statement" : section, false)
    }
    window.addEventListener("popstate", this.onPopState)
  }

  disconnect() {
    window.removeEventListener("popstate", this.onPopState)
  }

  select(event) {
    const section = event.currentTarget.dataset.section || event.currentTarget.value
    this.activateTab(section)
  }

  activateTab(section, updateUrl = true) {
    const selected = this.panelTargets.some((panel) => panel.dataset.section === section) ? section : "overview"

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.section === selected
      tab.setAttribute("aria-selected", String(active))
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
      panel.classList.toggle("hidden", !active)
      panel.setAttribute("aria-hidden", String(!active))
    })

    if (updateUrl) {
      const url = new URL(window.location.href)
      if (selected === "overview") {
        url.searchParams.delete("tab")
      } else {
        url.searchParams.set("tab", selected)
      }
      window.history.replaceState(window.history.state, "", url)
    }
  }
}
