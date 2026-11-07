import { Controller } from "@hotwired/stimulus"

// Progressive enhancement: the key remains editable and is never overwritten
// after the user has entered a value manually.
export default class extends Controller {
  static targets = ["name", "key"]

  connect() {
    this.keyEdited = this.keyTarget.value.trim().length > 0
  }

  nameChanged() {
    if (this.keyEdited) return

    const normalized = this.nameTarget.value
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .replace(/^[^a-z]+/, "")
      .slice(0, 100)

    this.keyTarget.value = normalized
  }

  keyChanged() {
    this.keyEdited = true
  }
}
