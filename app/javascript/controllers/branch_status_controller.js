import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label"]
  static values = { active: String, inactive: String }

  connect() { this.update() }

  update() {
    this.labelTarget.textContent = this.inputTarget.checked ? this.activeValue : this.inactiveValue
  }
}
