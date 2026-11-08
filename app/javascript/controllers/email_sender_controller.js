import { Controller } from "@hotwired/stimulus"

// Live example only. Domain verification and actual delivery are server-owned.
export default class extends Controller {
  static targets = [
    "name", "from", "reply", "locale", "previewName", "previewFrom",
    "previewReply", "previewLocale", "previewDomain"
  ]

  static values = {
    defaultName: String, defaultFrom: String, defaultReply: String, defaultDomain: String
  }

  connect() {
    this.updatePreview()
  }

  updatePreview() {
    const name = this.nameTarget.value.trim() || this.defaultNameValue
    const from = this.fromTarget.value.trim() || this.defaultFromValue
    const reply = this.replyTarget.value.trim() || this.defaultReplyValue
    const locale = this.localeTarget.selectedOptions[0]?.textContent || ""

    this.previewNameTarget.textContent = name
    this.previewFromTarget.textContent = from
    this.previewReplyTarget.textContent = reply
    this.previewLocaleTarget.textContent = locale

    const address = this.fromTarget.value.trim()
    const domain = /^[^\s@]+@([^\s@]+\.[^\s@]+)$/.exec(address)?.[1]
    this.previewDomainTarget.textContent = domain || this.defaultDomainValue
  }
}
