import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template", "empty", "notice"]
  static values = { locale: String, places: Object, limit: String }

  connect() {
    this.currency = this.element.querySelector("#price_list_currency")
    for (const input of this.rowsTarget.querySelectorAll("input:not([type=hidden]):not([readonly])")) {
      // Datetime inputs can normalize seconds and fractions on assignment.
      const pristine = document.createElement("input")
      pristine.type = input.type
      pristine.value = input.defaultValue
      input.dataset.initialValue = pristine.value
    }
    this.refresh = () => {
      this.rowsTarget.querySelectorAll("[data-price-list-row]").forEach((row) => this.refreshPrices(row))
    }
    this.currency?.addEventListener("change", this.refresh)
    this.trimSubmission = (event) => this.omitUnchangedRows(event.formData)
    this.guardSubmission = (event) => {
      if (this.changedRows().length <= 50) return
      event.preventDefault()
      this.noticeTarget.textContent = this.limitValue
      this.noticeTarget.focus()
    }
    this.element.addEventListener("formdata", this.trimSubmission)
    this.element.addEventListener("submit", this.guardSubmission, true)
    this.refresh()
    this.updateEmpty()
  }

  disconnect() {
    this.currency?.removeEventListener("change", this.refresh)
    this.element.removeEventListener("formdata", this.trimSubmission)
    this.element.removeEventListener("submit", this.guardSubmission, true)
  }

  add({ detail: { product } }) {
    if (this.changedRows().length >= 50) {
      this.noticeTarget.textContent = this.limitValue
      return
    }
    const fragment = this.templateTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-price-list-row]")
    // Rails requires numeric nested indices. Keep them unique after removing or re-adding a row.
    this.sequence = Math.max(this.sequence || 0, Date.now()) + 1
    row.querySelectorAll("*").forEach((node) => {
      for (const attr of [...node.attributes]) {
        if (attr.value.includes("NEW_ROW")) node.setAttribute(attr.name, attr.value.replaceAll("NEW_ROW", String(this.sequence)))
      }
    })
    row.querySelector("[data-row-product-id]").value = product.id
    row.querySelectorAll("[data-row-product]").forEach((node) => { node.textContent = product.name })
    row.querySelector("[data-row-code]").textContent = product.sku || product.code
    row.dataset.baseCurrency = product.currency
    row.dataset.basePrice = product.price
    if (row.querySelector("[data-row-margin]") && product.cost != null) row.dataset.cost = product.cost
    const input = row.querySelector("[data-row-price]")
    if (product.currency === this.currency?.value) input.value = product.price
    this.addOptions(row, "product_variant_id", product.variants)
    this.addOptions(row, "product_presentation_id", product.presentations)
    this.rowsTarget.append(fragment)
    this.refreshPrices(row)
    this.updateEmpty()
    input.focus()
    input.select()
  }

  addOptions(row, attribute, choices) {
    const select = row.querySelector(`select[name$="[${attribute}]"]`)
    for (const choice of choices) {
      const option = new Option(choice.name, String(choice.id))
      if (choice.units != null) option.dataset.units = choice.units
      select.add(option)
    }
  }

  rowChanged(row) {
    if (row.dataset.persisted !== "true" || row.dataset.changed === "true" || row.hidden) return true
    return [...row.querySelectorAll("input:not([type=hidden]):not([readonly])")]
      .some((input) => input.value !== input.dataset.initialValue)
  }

  changedRows() {
    return [...this.rowsTarget.children].filter((row) => this.rowChanged(row))
  }

  // Existing rows omitted from nested attributes stay in the list. Only changed
  // rows count toward the server's per-submission limit, including retirements.
  omitUnchangedRows(formData) {
    for (const row of this.rowsTarget.children) {
      if (this.rowChanged(row)) continue
      row.querySelectorAll("[name]").forEach((input) => formData.delete(input.name))
    }
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-price-list-row]")
    if (row.dataset.persisted === "true") {
      row.querySelector("[data-row-destroy]").value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
    this.updateEmpty()
    this.element.querySelector("#price-list-product-search").focus()
  }

  updateEmpty() {
    this.emptyTarget.hidden = !!this.rowsTarget.querySelector("[data-price-list-row]:not([hidden])")
    this.noticeTarget.textContent = ""
  }

  refreshRow(event) {
    this.refreshPrices(event.target.closest("[data-price-list-row]"))
  }

  refreshPrices(row) {
    const { baseCurrency, basePrice, cost } = row.dataset
    const presentation = row.querySelector('select[name$="[product_presentation_id]"]')
    const units = Number(presentation ? (presentation.selectedOptions[0]?.dataset.units || 1) : row.dataset.units)
    const places = this.placesValue[baseCurrency] ?? 2
    const format = new Intl.NumberFormat(this.localeValue, { minimumFractionDigits: places, maximumFractionDigits: places })
    row.querySelector("[data-row-base]").textContent = basePrice === "" ? "—" : `${format.format(Number(basePrice) * units)} ${baseCurrency}`
    const margin = row.querySelector("[data-row-margin]")
    if (!margin) return
    const price = row.querySelector("[data-row-price]").valueAsNumber
    const hasMargin = price > 0 && cost != null && cost !== "" && baseCurrency === this.currency?.value
    const percent = new Intl.NumberFormat(this.localeValue, { style: "percent", maximumFractionDigits: 2 })
    margin.textContent = hasMargin ? percent.format((price - Number(cost) * units) / price) : "—"
  }
}
