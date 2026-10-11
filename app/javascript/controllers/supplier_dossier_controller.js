import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "contactSearch", "contactRow", "contactCount", "contactEmpty"]

  filterContacts(event) {
    event?.preventDefault()
    const query = this.contactSearchTarget.value.trim().toLocaleLowerCase()
    let visibleCount = 0

    this.contactRowTargets.forEach((row) => {
      const matches = row.dataset.searchText.toLocaleLowerCase().includes(query)
      row.classList.toggle("hidden", !matches)
      if (matches) visibleCount += 1
    })

    this.contactCountTarget.textContent = visibleCount
    this.contactEmptyTarget.classList.toggle("hidden", visibleCount !== 0)
  }

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
