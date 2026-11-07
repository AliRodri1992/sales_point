import { Controller } from "@hotwired/stimulus"

// Change the saved email preview viewport without fetching or altering the template.
export default class extends Controller {
  static targets = ["frame", "desktopButton", "mobileButton"]

  connect() {
    this.selectDevice("desktop")
  }

  showDesktop() {
    this.selectDevice("desktop")
  }

  showMobile() {
    this.selectDevice("mobile")
  }

  selectDevice(device) {
    const desktop = device === "desktop"
    if (!this.hasFrameTarget || !this.hasDesktopButtonTarget || !this.hasMobileButtonTarget) return

    this.frameTarget.classList.toggle("max-w-[720px]", desktop)
    this.frameTarget.classList.toggle("max-w-[375px]", !desktop)
    this.desktopButtonTarget.setAttribute("aria-pressed", String(desktop))
    this.mobileButtonTarget.setAttribute("aria-pressed", String(!desktop))
    this.decorateButton(this.desktopButtonTarget, desktop)
    this.decorateButton(this.mobileButtonTarget, !desktop)
  }

  decorateButton(button, active) {
    button.classList.toggle("bg-white", active)
    button.classList.toggle("text-emerald-800", active)
    button.classList.toggle("shadow-sm", active)
    button.classList.toggle("text-slate-600", !active)
  }
}
