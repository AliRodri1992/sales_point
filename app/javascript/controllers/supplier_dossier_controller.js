import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "mobileSelect", "addressSearch", "addressRow", "addressCount", "addressEmpty"]
  static values = { initialTab: { type: String, default: "overview" } }

  connect() {
    const requested = new URL(window.location.href).searchParams.get("tab") || this.initialTabValue
    this.activateTab(requested, false)
    this.onPopState = () => {
      this.activateTab(new URL(window.location.href).searchParams.get("tab") || "overview", false)
    }
    window.addEventListener("popstate", this.onPopState)
  }

  disconnect() {
    window.removeEventListener("popstate", this.onPopState)
  }

  filterAddresses() {
    const query = this.addressSearchTarget.value.trim().toLocaleLowerCase()
    let visibleCount = 0

    this.addressRowTargets.forEach((row) => {
      const matches = row.dataset.searchText.toLocaleLowerCase().includes(query)
      row.classList.toggle("hidden", !matches)
      if (matches) visibleCount += 1
    })

    this.addressCountTarget.textContent = visibleCount
    this.addressEmptyTarget.classList.toggle("hidden", visibleCount !== 0)
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
