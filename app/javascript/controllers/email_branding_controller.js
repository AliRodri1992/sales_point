import { Controller } from "@hotwired/stimulus"

// Preview represents editable brand settings; published HTML is never rewritten.
export default class extends Controller {
  static targets = [
    "name", "previewName", "footer", "previewFooterText", "supportEmail", "previewEmail",
    "previewPrimary", "previewSecondary", "previewButton", "colorInput", "picker",
    "contrast", "logo", "logoPreview", "logoName", "logoError", "removeLogo"
  ]

  static values = {
    invalidLogo: String, invalidColor: String, contrastGood: String, contrastLow: String
  }

  connect() {
    this.objectUrl = null
    this.updatePreview()
    this.updateColors()
  }

  disconnect() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }

  updatePreview() {
    if (this.hasPreviewNameTarget) this.previewNameTarget.textContent = this.nameTarget.value.trim() || "Delta POS"
    if (this.hasPreviewEmailTarget) {
      const value = this.supportEmailTarget.value.trim()
      if (value) this.previewEmailTarget.textContent = value
    }
    if (this.hasPreviewFooterTextTarget && this.footerTarget.value.trim()) {
      this.previewFooterTextTarget.textContent = this.footerTarget.value.trim()
    }
  }

  pickerChanged(event) {
    const key = event.target.dataset.brandColor
    const input = this.colorInputTargets.find(item => item.dataset.brandColor === key)
    if (!input) return

    input.value = event.target.value.toUpperCase()
    input.setCustomValidity("")
    this.updateColors()
  }

  colorChanged(event) {
    const input = event.target
    const key = input.dataset.brandColor
    const picker = this.pickerTargets.find(item => item.dataset.brandColor === key)
    if (picker && this.validColor(input.value)) picker.value = input.value
    input.setCustomValidity("")
    this.updateColors()
  }

  updateColors() {
    const values = Object.fromEntries(
      this.colorInputTargets.filter(item => this.validColor(item.value))
        .map(item => [item.dataset.brandColor, item.value])
    )
    if (values.primary_color) this.previewPrimaryTarget.style.color = values.primary_color
    if (values.secondary_color) this.previewSecondaryTarget.style.color = values.secondary_color
    if (values.button_color) {
      this.previewButtonTarget.style.backgroundColor = values.button_color
      const sufficient = this.whiteContrast(values.button_color) >= 4.5
      this.contrastTarget.textContent = sufficient ? this.contrastGoodValue : this.contrastLowValue
      this.contrastTarget.classList.toggle("text-rose-700", !sufficient)
      this.contrastTarget.classList.toggle("text-emerald-800", sufficient)
    }
  }

  logoChanged(event) {
    const file = event.target.files[0]
    this.logoErrorTarget.hidden = true
    if (!file) return

    const allowed = ["image/png", "image/jpeg", "image/webp"]
    if (!allowed.includes(file.type) || file.size > 2 * 1024 * 1024) {
      event.target.value = ""
      this.logoErrorTarget.textContent = this.invalidLogoValue
      this.logoErrorTarget.hidden = false
      this.logoNameTarget.textContent = ""
      return
    }
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = URL.createObjectURL(file)
    this.logoPreviewTarget.src = this.objectUrl
    this.logoPreviewTarget.classList.remove("hidden")
    this.logoNameTarget.textContent = file.name
    if (this.hasRemoveLogoTarget) this.removeLogoTarget.checked = false
  }

  validateForm(event) {
    this.colorInputTargets.forEach(input => {
      input.setCustomValidity(this.validColor(input.value) ? "" : this.invalidColorValue)
    })
    if (!this.element.checkValidity()) {
      event.preventDefault()
      this.element.reportValidity()
    }
  }

  validColor(value) {
    return /^#[0-9a-fA-F]{6}$/.test(value)
  }

  whiteContrast(hex) {
    const rgb = hex.slice(1).match(/../g).map(c => parseInt(c, 16) / 255)
    const channels = rgb.map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)
    const brightness = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    return 1.05 / (brightness + 0.05)
  }
}
