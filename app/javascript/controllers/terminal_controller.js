import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["wrapper", "themeDropdown", "password", "loginCard", "errorBanner", "input", "themeOption", "loginSubmit"]

  connect() {
    this.onDocumentClick = (event) => {
      if (!event.target.closest("[data-theme-toggle], #terminal-theme-dropdown")) this.closeDropdowns()
    }
    this.onDocumentKeydown = (event) => {
      if (event.key !== "Escape" || !this.hasThemeDropdownTarget || this.themeDropdownTarget.classList.contains("hidden")) return
      this.closeDropdowns()
      this.element.querySelector("[data-theme-toggle]")?.focus()
    }
    this.onPageRestore = () => this.finishLogin()
    document.addEventListener("click", this.onDocumentClick)
    document.addEventListener("keydown", this.onDocumentKeydown)
    document.addEventListener("turbo:before-cache", this.onPageRestore)
    window.addEventListener("pageshow", this.onPageRestore)
    this.restoreSelectedTheme()
    if (this.hasErrorBannerTarget && !this.errorBannerTarget.classList.contains("hidden")) this.showErrors()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    document.removeEventListener("keydown", this.onDocumentKeydown)
    document.removeEventListener("turbo:before-cache", this.onPageRestore)
    window.removeEventListener("pageshow", this.onPageRestore)
    if (this.bannerTimeout) clearTimeout(this.bannerTimeout)
  }

  restoreSelectedTheme() {
    if (!this.hasWrapperTarget || !this.hasThemeOptionTarget) return
    let savedTheme
    try { savedTheme = window.localStorage.getItem("terminal_theme") } catch (_error) { return }
    if (!this.themeOptionTargets.some((option) => option.dataset.theme === savedTheme)) return
    this.applyTheme(savedTheme)
  }

  applyTheme(theme) {
    if (!this.hasWrapperTarget) return
    if (!this.themeOptionTargets.some((option) => option.dataset.theme === theme)) return
    this.themeOptionTargets.forEach((option) => {
      this.wrapperTarget.classList.remove(option.dataset.theme)
      const selected = option.dataset.theme === theme
      option.classList.toggle("rounded-full", selected)
      option.classList.toggle("rounded-lg", !selected)
      option.setAttribute("aria-pressed", String(selected))
      option.querySelector("[data-theme-indicator]")?.remove()
      if (selected) {
        const dot = document.createElement("span")
        dot.dataset.themeIndicator = "true"
        dot.className = theme === "theme-material-school-yellow"
          ? "block h-1.5 w-1.5 rounded-full bg-zinc-800"
          : "block h-1.5 w-1.5 rounded-full bg-white"
        option.appendChild(dot)
      }
    })
    this.wrapperTarget.classList.add(theme, "theme-selected")
  }

  selectTheme(event) {
    event.stopPropagation()
    const theme = event.currentTarget.dataset.theme
    if (!this.themeOptionTargets.some((option) => option.dataset.theme === theme)) return
    this.applyTheme(theme)
    document.cookie = `terminal_theme=${encodeURIComponent(theme)}; path=/; max-age=31536000; samesite=lax`
    document.cookie = "terminal_theme_selected=1; path=/; max-age=31536000; samesite=lax"
    try { window.localStorage.setItem("terminal_theme", theme) } catch (_error) { /* cookie retains the preference */ }
    this.closeDropdowns()
    this.element.querySelector("[data-theme-toggle]")?.focus()
  }

  toggleThemeDropdown(event) {
    event.stopPropagation()
    if (!this.hasThemeDropdownTarget) return
    if (this.themeDropdownTarget.classList.contains("hidden")) {
      this.themeDropdownTarget.classList.remove("hidden", "opacity-0", "scale-95")
      this.element.querySelector("[data-theme-toggle]")?.setAttribute("aria-expanded", "true")
      this.themeOptionTargets.find((option) => option.getAttribute("aria-pressed") === "true")?.focus()
    } else {
      this.closeDropdowns()
    }
  }

  closeDropdowns() {
    if (!this.hasThemeDropdownTarget) return
    this.themeDropdownTarget.classList.add("hidden", "opacity-0", "scale-95")
    this.element.querySelector("[data-theme-toggle]")?.setAttribute("aria-expanded", "false")
  }

  togglePassword(event) {
    event.preventDefault()
    const button = event.currentTarget
    const field = button.closest(".relative")?.querySelector('input[type="password"], input[type="text"]')
    if (!field) return
    const visible = field.type === "password"
    field.type = visible ? "text" : "password"
    button.setAttribute("aria-pressed", String(visible))
    button.setAttribute("aria-label", visible ? button.dataset.hideLabel : button.dataset.showLabel)
    button.querySelector("[data-password-show-icon]")?.classList.toggle("hidden", visible)
    button.querySelector("[data-password-hide-icon]")?.classList.toggle("hidden", !visible)
  }

  submitLogin(event) {
    if (!this.hasLoginSubmitTarget) return
    let firstInvalid = null
    this.inputTargets.forEach((input) => {
      const message = this.loginInputMessage(input)
      if (!message) return
      this.showFieldError(input, message)
      firstInvalid ||= input
    })
    if (firstInvalid) {
      event.preventDefault()
      firstInvalid.focus()
      return
    }
    if (this.loginSubmitTarget.disabled) {
      event.preventDefault()
      return
    }
    this.loginSubmitTarget.disabled = true
    this.loginSubmitTarget.setAttribute("aria-busy", "true")
    const label = this.loginSubmitTarget.querySelector("span")
    if (label) {
      this.originalLabel = label.textContent
      label.textContent = this.loginSubmitTarget.dataset.loadingText
    }
  }

  loginInputMessage(input) {
    const value = input.value.trim()
    if (!value) return input.dataset.authBlankMessage
    if (input.type === "email" && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      return input.dataset.authInvalidMessage
    }
    if (input.minLength > 0 && Array.from(input.value).length < input.minLength) {
      return input.dataset.authMinLengthMessage
    }
    return null
  }

  finishLogin(event) {
    if (!this.hasLoginSubmitTarget) return
    this.loginSubmitTarget.disabled = false
    this.loginSubmitTarget.removeAttribute("aria-busy")
    const label = this.loginSubmitTarget.querySelector("span")
    if (label && this.originalLabel) label.textContent = this.originalLabel
    if (event?.detail?.error || event?.detail?.fetchResponse?.statusCode >= 500) this.showNetworkError()
  }

  loginNetworkError(event) {
    event.preventDefault()
    this.finishLogin()
    this.showNetworkError()
  }

  showNetworkError() {
    if (!this.hasErrorBannerTarget) return
    this.errorBannerTarget.textContent = this.element.dataset.networkError
    this.showErrors()
  }

  showFieldError(input, message) {
    const slot = input.closest("[data-login-field]")?.querySelector('[role="status"]')
    if (!slot || !message) return
    slot.replaceChildren()
    const line = document.createElement("p")
    line.className = "font-medium"
    line.dataset.serverFieldError = "true"
    line.textContent = message
    slot.appendChild(line)
    input.setAttribute("aria-invalid", "true")
    input.setAttribute("aria-describedby", slot.id)
    input.classList.add("input-field-error", "border-rose-500", "bg-rose-50")
    input.classList.remove("border-slate-200")
  }

  clearErrors(event) {
    const input = event?.target
    if (!input?.matches("input") || !input.closest("[data-login-field]")) return
    const slot = input.closest("[data-login-field]").querySelector('[role="status"]')
    slot?.replaceChildren()
    input.style.removeProperty("box-shadow")
    input.style.removeProperty("border-color")
    input.classList.remove("input-field-error", "border-rose-500", "bg-rose-50")
    input.classList.add("border-slate-200")
    input.setAttribute("aria-invalid", "false")
    input.removeAttribute("aria-describedby")
  }

  showErrors() {
    if (this.element.classList.contains("registration-page")) return
    if (!this.hasErrorBannerTarget || !this.hasLoginCardTarget) return
    this.loginCardTarget.classList.add("animate-shake")
    setTimeout(() => this.loginCardTarget.classList.remove("animate-shake"), 400)
    this.errorBannerTarget.classList.remove("hidden", "translate-y-2", "opacity-0")
    this.errorBannerTarget.focus()
  }
}
