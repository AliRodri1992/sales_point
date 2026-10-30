import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { saveTablePagePreference } from "../lib/table_page_preferences"

// Each table has its own saved page-size override; filters and sorting stay intact.
export default class extends Controller {
  static values = { key: String }

  async apply(event) {
    if (this.saving || !this.hasKeyValue) return
    const value = event.target.value
    this.saving = true
    event.target.disabled = true

    try {
      await saveTablePagePreference(this.keyValue, value)
    } catch (error) {
      console.warn("Table page size was not saved", error)
    } finally {
      const url = new URL(window.location.href)
      url.searchParams.set("per_page", value)
      url.searchParams.delete("page")
      event.target.disabled = false
      this.saving = false
      Turbo.visit(url.toString())
    }
  }
}
