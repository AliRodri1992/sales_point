import { Controller } from "@hotwired/stimulus"

// A visual-only bank card preview. Never copies complete protected values to text or HTML.
export default class extends Controller {
  static targets = [
    "holder", "bank", "bankName", "clabe", "accountType",
    "primary", "status", "blockedReasonGroup", "previewBank", "previewNumber",
    "previewHolder", "previewType", "previewPrimary"
  ]

  static values = {
    existingDigits: String,
    bankPlaceholder: String
  }

  connect() {
    this.refresh()
  }

  refresh() {
    const manualBank = this.bankNameTarget.value.trim()
    const chosenBank = this.bankTarget.selectedOptions[0]
    this.previewBankTarget.textContent = manualBank || (this.bankTarget.value && chosenBank
      ? chosenBank.textContent.trim() : this.bankPlaceholderValue)
    this.previewHolderTarget.textContent = this.holderTarget.value.trim() || "—"
    const type = this.accountTypeTarget.selectedOptions[0]
    this.previewTypeTarget.textContent = this.accountTypeTarget.value && type
      ? type.textContent.trim() : "—"

    const clabeDigits = this.clabeTarget.value.replace(/\D/g, "")
    const digits = clabeDigits.length >= 4 ? clabeDigits.slice(-4) : this.existingDigitsValue
    this.previewNumberTarget.textContent = "•••• " + (digits || "••••")

    const active = !this.hasStatusTarget || this.statusTarget.value === "active"
    this.previewPrimaryTarget.classList.toggle("hidden", !this.primaryTarget.checked || !active)

    if (this.hasStatusTarget && this.hasBlockedReasonGroupTarget) {
      this.blockedReasonGroupTarget.classList.toggle("hidden", this.statusTarget.value !== "blocked")
    }
  }
}
