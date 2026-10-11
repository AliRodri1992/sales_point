import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const section = event.currentTarget.dataset.section

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.section === section
      tab.setAttribute("aria-selected", String(active))
      tab.classList.toggle("bg-emerald-600", active)
      tab.classList.toggle("text-white", active)
      tab.classList.toggle("text-slate-600", !active)
      tab.classList.toggle("hover:bg-slate-100", !active)
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.section !== section)
    })
  }
}
