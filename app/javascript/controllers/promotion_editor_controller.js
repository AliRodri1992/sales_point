import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["benefits", "benefitTemplate", "conditions", "exclude", "rule", "benefitNotice", "conditionNotice", "addRule", "addBenefit"]
  static values = { limit: String, duplicate: String, added: String, removed: String }

  connect() {
    this.sequence = Date.now()
  }

  pick({ detail }) {
    const kind = this.excludeTarget.checked ? `excluded_${detail.kind}` : detail.kind
    const duplicate = Array.from(this.conditionsTarget.children).some((row) =>
      !row.hidden && row.dataset.conditionKind === kind && row.querySelector("[data-selected-id]")?.value === detail.id
    )
    if (duplicate) {
      this.conditionNoticeTarget.textContent = this.duplicateValue
      return
    }
    const row = this.appendCondition(kind)
    if (!row) return
    row.querySelector("[data-selected-id]").value = detail.id
    row.querySelector("[data-selected-label]").textContent = detail.name
    this.conditionNoticeTarget.textContent = this.addedValue.replace("__NAME__", detail.name)
  }

  addBenefit() {
    const row = this.append(this.benefitsTarget, this.benefitTemplateTarget, 10)
    row?.querySelector('input[type="number"]')?.focus()
  }

  addRule() {
    const row = this.appendCondition(this.ruleTarget.value)
    row?.querySelector('input:not([type="hidden"])')?.focus()
  }

  appendCondition(kind) {
    const template = this.element.querySelector(`template[data-condition-template="${CSS.escape(kind)}"]`)
    return this.append(this.conditionsTarget, template, 20)
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
    row.querySelectorAll("[id],[name],[for],[aria-describedby]").forEach((field) => {
      for (const attr of ["id", "name", "for", "aria-describedby"]) {
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
    const returnFocus = benefit ? this.addBenefitTarget : this.addRuleTarget
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
