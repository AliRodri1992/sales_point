import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { saveTablePagePreference } from "../lib/table_page_preferences"

// Each table has its own saved page-size override; filters and sorting stay intact.
export default class extends Controller {
  static values = { key: String }

  async apply(event) {
    if (this.saving || !this.hasKeyValue) return

    const select = event.target
    this.saving = true
    select.disabled = true

    try {
      await saveTablePagePreference(this.keyValue, select.value)
      const url = new URL(window.location.href)
      url.searchParams.set("per_page", select.value)
      url.searchParams.delete("page")
      Turbo.visit(url.toString())
    } catch (error) {
      console.warn("Table page size was not saved", error)
      const english = document.documentElement.lang?.toLowerCase().startsWith("en")
      const title = english ? "Could not save your preference" : "No se pudo guardar tu preferencia"
      const message = english ? "Please try selecting a page size again." : "Intenta seleccionar nuevamente una cantidad de registros."
      if (window.Swal) window.Swal.fire({ icon: "error", title, text: message })
      else window.alert(`${title}. ${message}`)
    } finally {
      select.disabled = false
      this.saving = false
    }
  }
}
