import { Controller } from "@hotwired/stimulus"

// Native dialog keeps focus trapped; Rails remains responsible for validation.
export default class extends Controller {
  static targets = ["name", "code", "description", "counter"]

  connect() {
    this.manualCode = Boolean(this.hasCodeTarget && this.codeTarget.value.trim())
    this.descriptionChanged()
    if (this.element.dataset.systemRoleCreateOpenValue === "true" && !this.element.open) {
      this.element.showModal()
      const invalid = this.element.querySelector('input[aria-invalid="true"]')
      ;(invalid || this.nameTarget)?.focus()
    }
  }

  nameChanged() {
    if (!this.hasNameTarget || !this.hasCodeTarget || this.manualCode) return
    this.codeTarget.value = this.nameTarget.value
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .slice(0, 50)
  }

  codeChanged() {
    this.manualCode = Boolean(this.codeTarget.value.trim())
  }

  descriptionChanged() {
    if (!this.hasDescriptionTarget || !this.hasCounterTarget) return
    const count = this.descriptionTarget.value.length
    const template = this.element.dataset.systemRoleCreateCountTemplateValue || "__COUNT__ / 500"
    this.counterTarget.textContent = template.replace("__COUNT__", count)
  }

  submitting() {
    const button = this.element.querySelector(".role-create-submit")
    if (button) button.disabled = true
  }

  close() {
    this.element.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }

  closed() {
    document.querySelector('[data-action*="system-role-directory#openCreate"]')?.focus()
  }

  closeForCache() {
    if (this.element.open) this.element.close()
  }
}
