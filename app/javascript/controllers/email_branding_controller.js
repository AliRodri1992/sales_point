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
    this.originalLogoSrc = this.logoPreviewTarget.getAttribute("src")
    this.originalLogoHidden = this.logoPreviewTarget.classList.contains("hidden")
    this.updatePreview()
    this.updateColors()
  }

  disconnect() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
  }

  updatePreview() {
    if (this.hasPreviewNameTarget) this.previewNameTarget.textContent = this.nameTarget.value.trim() || "Delta POS"
    if (this.hasPreviewEmailTarget) {
      this.previewEmailTarget.textContent = this.supportEmailTarget.value.trim() ||
        this.previewEmailTarget.dataset.defaultText
    }
    if (this.hasPreviewFooterTextTarget) {
      this.previewFooterTextTarget.textContent = this.footerTarget.value.trim() ||
        this.previewFooterTextTarget.dataset.defaultText
    }
  }

  pickerChanged(event) {
    const key = event.target.dataset.brandColor
    const input = this.colorInputTargets.find(item => item.dataset.brandColor === key)
    if (!input) return

    input.value = event.target.value.toUpperCase()
    this.updateColors()
  }

  colorChanged(event) {
    const input = event.target
    const key = input.dataset.brandColor
    const picker = this.pickerTargets.find(item => item.dataset.brandColor === key)
    if (picker && this.validColor(input.value)) picker.value = input.value
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
      const buttonInput = this.colorInputTargets.find(item => item.dataset.brandColor === "button_color")
      if (buttonInput) buttonInput.setAttribute("aria-invalid", String(!sufficient))
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
      this.resetLogoPreview()
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

  removeLogoChanged(event) {
    if (event.target.checked) {
      this.resetLogoPreview()
      this.logoPreviewTarget.classList.add("hidden")
    } else if (!this.logoTarget.files.length) {
      this.resetLogoPreview()
    }
  }

  resetLogoPreview() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
    this.logoPreviewTarget.src = this.originalLogoSrc
    this.logoPreviewTarget.classList.toggle("hidden", this.originalLogoHidden)
    this.logoNameTarget.textContent = ""
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
