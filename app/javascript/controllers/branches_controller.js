import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "modalTitle",
    "form",
    "name",
    "phone",
    "address",
    "status",
    "submit"
  ]

  openCreate() {
    this.modalTitleTarget.textContent = "Nueva sucursal"
    this.formTarget.action = this.createUrl
    this.resetMethod()
    this.nameTarget.value = ""
    this.phoneTarget.value = ""
    this.addressTarget.value = ""
    this.statusTarget.checked = true
    this.submitTarget.textContent = "Guardar sucursal"
    this.showModal()
  }

  openEdit(event) {
    const button = event.currentTarget
    const id = button.dataset.branchId

    this.modalTitleTarget.textContent = "Editar sucursal"
    this.formTarget.action = window.location.pathname + "/" + id
    this.setMethod("patch")
    this.nameTarget.value = button.dataset.branchName || ""
    this.phoneTarget.value = button.dataset.branchPhone || ""
    this.addressTarget.value = button.dataset.branchAddress || ""
    this.statusTarget.checked = button.dataset.branchStatus === "true"
    this.submitTarget.textContent = "Guardar cambios"
    this.showModal()
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    this.modalTarget.setAttribute("aria-hidden", "true")
    this.resetMethod()
  }

  background(event) {
    if (event.target === this.modalTarget) this.close()
  }

  get createUrl() {
    return this.element.dataset.createUrl || window.location.pathname
  }

  setMethod(method) {
    let methodInput = this.formTarget.querySelector('input[name="_method"]')

    if (!methodInput) {
      methodInput = document.createElement("input")
      methodInput.type = "hidden"
      methodInput.name = "_method"
      this.formTarget.appendChild(methodInput)
    }

    methodInput.value = method
  }

  resetMethod() {
    this.formTarget.querySelector('input[name="_method"]')?.remove()
  }

  showModal() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    this.modalTarget.setAttribute("aria-hidden", "false")
    this.nameTarget.focus()
  }
}
