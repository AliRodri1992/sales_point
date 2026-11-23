import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["benefits", "benefitTemplate", "conditions", "conditionTemplate", "benefitNotice", "conditionNotice", "addCondition", "addBenefit"]
  static values = { limit: String, duplicate: String, removed: String }

  connect() {
    this.sequence = Date.now()
  }

  addBenefit() {
    const row = this.append(this.benefitsTarget, this.benefitTemplateTarget, 10)
    row?.querySelector('input[type="number"]')?.focus()
  }

  addCondition() {
    const row = this.append(this.conditionsTarget, this.conditionTemplateTarget, 20)
    row?.querySelector('input[type="search"]')?.focus()
  }

  changeCondition(event) {
    const row = event.target.closest("[data-condition-kind]")
    const kind = event.target.value
    row.dataset.conditionKind = kind
    const valueKind = kind.replace(/^excluded_/, "")
    row.querySelectorAll("[data-condition-value]").forEach((slot) => {
      slot.hidden = slot.dataset.conditionValue !== valueKind
      if (!slot.hidden) return
      slot.querySelectorAll("input").forEach((input) => {
        input.value = ""
        if (input.type === "search") input.dispatchEvent(new Event("input", { bubbles: true }))
      })
    })
    this.conditionNoticeTarget.textContent = ""
  }

  chooseTarget(event) {
    const row = event.target.closest("[data-condition-kind]")
    if (!row || !event.target.matches('[data-promotion-lookup-target="selection"]')) return
    const kind = row.dataset.conditionKind
    const valueSlot = kind.replace(/^excluded_/, "")
    const selector = `[data-condition-value="${CSS.escape(valueSlot)}"] [data-promotion-lookup-target="selection"]`
    const duplicate = event.target.value && Array.from(this.conditionsTarget.children).some((other) =>
      other !== row && !other.hidden && other.dataset.conditionKind === kind && other.querySelector(selector)?.value === event.target.value
    )
    if (duplicate) {
      event.target.value = ""
      event.target.closest("[data-controller='promotion-lookup']").querySelector("input[type=search]").value = ""
      this.conditionNoticeTarget.textContent = this.duplicateValue
    } else {
      this.conditionNoticeTarget.textContent = ""
    }
  }

  append(container, template, limit) {
    const notice = container === this.benefitsTarget ? this.benefitNoticeTarget : this.conditionNoticeTarget
    notice.textContent = ""
    if (!template || container.children.length >= limit) {
      notice.textContent = this.limitValue
      return
    }
    // Only server-rendered form fields are cloned. Catalog values are assigned as text.
    const row = template.content.firstElementChild.cloneNode(true)
    row.querySelectorAll("[id],[name],[for],[aria-describedby],[aria-controls]").forEach((field) => {
      for (const attr of ["id", "name", "for", "aria-describedby", "aria-controls"]) {
        const value = field.getAttribute(attr)
        if (value) field.setAttribute(attr, value.replaceAll("NEW_RECORD", this.sequence))
      }
    })
    this.sequence++
    container.append(row)
    return row
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-campaign-row]")
    const benefit = this.benefitsTarget.contains(row)
    const returnFocus = benefit ? this.addBenefitTarget : this.addConditionTarget
    const destroy = row.querySelector('input[name$="[_destroy]"]')
    if (destroy) {
      destroy.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
    const notice = benefit ? this.benefitNoticeTarget : this.conditionNoticeTarget
    notice.textContent = this.removedValue
    returnFocus.focus()
  }
}
