import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    newTitle: String,
    editTitle: String,
    createSubmit: String,
    updateSubmit: String
  }

  static targets = [
    "modal",
    "modalTitle",
    "form",
    "name",
    "phone",
    "status",
    "submit",
    "street",
    "exteriorNumber",
    "interiorNumber",
    "neighborhood",
    "city",
    "state",
    "country",
    "postalCode"
  ]

  openCreate() {
    this.modalTitleTarget.textContent = this.newTitleValue
    this.formTarget.action = this.createUrl
    this.resetMethod()
    this.nameTarget.value = ""
    this.phoneTarget.value = ""
    this.statusTarget.checked = true
    this.resetAddress()
    this.submitTarget.textContent = this.createSubmitValue
    this.showModal()
  }

  openEdit(event) {
    const button = event.currentTarget
    const id = button.dataset.branchId

    this.modalTitleTarget.textContent = this.editTitleValue
    this.formTarget.action = window.location.pathname + "/" + id
    this.setMethod("patch")
    this.nameTarget.value = button.dataset.branchName || ""
    this.phoneTarget.value = button.dataset.branchPhone || ""
    this.statusTarget.checked = button.dataset.branchStatus === "true"

    this.streetTarget.value = button.dataset.addressStreet || ""
    this.exteriorNumberTarget.value = button.dataset.addressExteriorNumber || ""
    this.interiorNumberTarget.value = button.dataset.addressInteriorNumber || ""
    this.neighborhoodTarget.value = button.dataset.addressNeighborhood || ""
    this.cityTarget.value = button.dataset.addressCity || ""
    this.stateTarget.value = button.dataset.addressState || ""
    this.countryTarget.value = button.dataset.addressCountry || "MX"
    this.postalCodeTarget.value = button.dataset.addressPostalCode || ""

    const addressIdInput = this.formTarget.querySelector('input[name="branch[address_attributes][id]"]')
    if (addressIdInput) addressIdInput.value = button.dataset.addressId || ""

    this.submitTarget.textContent = this.updateSubmitValue
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

  resetAddress() {
    this.streetTarget.value = ""
    this.exteriorNumberTarget.value = ""
    this.interiorNumberTarget.value = ""
    this.neighborhoodTarget.value = ""
    this.cityTarget.value = ""
    this.stateTarget.value = ""
    this.countryTarget.value = "MX"
    this.postalCodeTarget.value = ""

    const addressIdInput = this.formTarget.querySelector('input[name="branch[address_attributes][id]"]')
    if (addressIdInput) addressIdInput.value = ""
  }

  showModal() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    this.modalTarget.setAttribute("aria-hidden", "false")
    this.nameTarget.focus()
  }
}
