import { Controller } from "@hotwired/stimulus"

const dateAt = (year, month, day = 1) => {
  const date = new Date(0)
  date.setUTCFullYear(year, month, day)
  return date
}
const isoDay = (date) => date.toISOString().slice(0, 10)

export default class extends Controller {
  static targets = ["trigger", "panel", "month", "days", "label", "time"]
  static values = { today: String, placeholder: String }

  connect() {
    this.input = this.element.querySelector('input[type="datetime-local"]')
    if (!this.input) return
    this.element.classList.add("promotion-date-enhanced")
    this.triggerTarget.hidden = false
    this.input.classList.add("promotion-date-native")
    this.input.tabIndex = -1
    this.input.setAttribute("aria-hidden", "true")
    this.input.after(this.triggerTarget)
    this.fieldLabel = this.input.labels?.[0]?.textContent?.trim() || this.triggerTarget.dataset.label
    this.locale = document.documentElement.lang || "en"
    this.onLabelClick = (event) => { event.preventDefault(); this.triggerTarget.focus() }
    this.input.labels?.forEach((node) => node.addEventListener("click", this.onLabelClick))
    this.refresh = () => this.refreshLabel()
    this.input.addEventListener("input", this.refresh)
    this.input.addEventListener("change", this.refresh)
    this.refreshLabel()
    this.reposition = () => { if (!this.panelTarget.hidden) this.position() }
    window.addEventListener("resize", this.reposition)
    document.addEventListener("scroll", this.reposition, true)
  }

  disconnect() {
    window.removeEventListener("resize", this.reposition)
    document.removeEventListener("scroll", this.reposition, true)
    if (!this.input) return
    this.input.labels?.forEach((node) => node.removeEventListener("click", this.onLabelClick))
    this.input.removeEventListener("input", this.refresh)
    this.input.removeEventListener("change", this.refresh)
    this.input.classList.remove("promotion-date-native")
    this.input.removeAttribute("tabindex")
    this.input.removeAttribute("aria-hidden")
    this.element.classList.remove("promotion-date-enhanced")
    this.triggerTarget.hidden = true
    this.close()
  }

  toggle() {
    if (!this.panelTarget.hidden) return this.close()
    const date = new Date(`${this.input.value.split("T")[0] || this.todayValue}T00:00:00Z`)
    const [selected, time] = this.input.value.split("T")
    this.selected = selected || ""
    this.timeTarget.value = (time || "00:00").slice(0, 5)
    this.seconds = time?.slice(5) || ":00"
    this.validateTime()
    this.cursor = dateAt(date.getUTCFullYear(), date.getUTCMonth())
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.draw()
    this.position()
    const selectedButton = this.daysTarget.querySelector('[aria-pressed="true"]') || this.daysTarget.querySelector("button")
    selectedButton?.focus()
  }

  previous() { this.moveMonth(-1) }
  next() { this.moveMonth(1) }

  moveMonth(offset) {
    this.cursor = dateAt(this.cursor.getUTCFullYear(), this.cursor.getUTCMonth() + offset)
    this.draw()
  }

  draw() {
    const year = this.cursor.getUTCFullYear()
    const month = this.cursor.getUTCMonth()
    const format = (date, options) => new Intl.DateTimeFormat(this.locale, { ...options, timeZone: "UTC" }).format(date)
    this.monthTarget.textContent = format(this.cursor, { month: "long", year: "numeric" })
    this.daysTarget.replaceChildren()
    const first = (this.cursor.getUTCDay() + 6) % 7
    for (let index = 0; index < 7; index++) {
      const label = document.createElement("span")
      label.className = "promotion-date-weekday"
      label.textContent = format(dateAt(2024, 0, index + 1), { weekday: "short" })
      this.daysTarget.append(label)
    }
    for (let index = 0; index < first; index++) this.daysTarget.append(document.createElement("span"))
    const last = dateAt(year, month + 1, 0).getUTCDate()
    for (let day = 1; day <= last; day++) {
      const date = dateAt(year, month, day)
      const value = isoDay(date)
      const button = document.createElement("button")
      button.type = "button"
      button.className = "promotion-date-day"
      button.textContent = day
      button.dataset.date = value
      button.setAttribute("aria-label", format(date, { dateStyle: "full" }))
      button.setAttribute("aria-pressed", String(this.selected === value))
      if (value === this.todayValue) button.setAttribute("aria-current", "date")
      button.addEventListener("click", () => this.select(value))
      this.daysTarget.append(button)
    }
  }

  select(value) {
    this.selected = value
    this.daysTarget.querySelectorAll("[data-date]").forEach((button) =>
      button.setAttribute("aria-pressed", String(button.dataset.date === value))
    )
    if (this.validateTime()) this.commit(`${value}T${this.timeTarget.value}${this.seconds}`, false)
  }

  today() {
    const now = new Date(`${this.todayValue}T00:00:00Z`)
    this.cursor = dateAt(now.getUTCFullYear(), now.getUTCMonth())
    this.selected = this.todayValue
    this.draw()
    this.select(this.todayValue)
  }
  clear() { this.commit("") }

  validateTime() {
    const valid = /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(this.timeTarget.value)
    this.timeTarget.setAttribute("aria-invalid", String(!valid))
    return valid
  }

  apply() {
    if (!this.validateTime()) return this.timeTarget.focus()
    if (!this.selected) return this.daysTarget.querySelector("button")?.focus()
    this.commit(`${this.selected}T${this.timeTarget.value}${this.seconds}`)
  }

  refreshLabel() {
    const [date, time] = this.input.value.split("T")
    const format = new Intl.DateTimeFormat(this.locale, { day: "2-digit", month: "2-digit", year: "numeric", timeZone: "UTC" })
    this.labelTarget.textContent = date ? `${format.format(new Date(`${date}T00:00:00Z`))} · ${time.slice(0, 5)}` : this.placeholderValue
    this.triggerTarget.classList.toggle("is-placeholder", !date)
    this.triggerTarget.setAttribute("aria-label", `${this.fieldLabel}: ${this.labelTarget.textContent}`)
    for (const attr of ["aria-invalid", "aria-describedby"]) {
      const value = this.input.getAttribute(attr)
      if (value !== null) this.triggerTarget.setAttribute(attr, value)
    }
  }

  commit(value, close = true) {
    this.input.value = value
    this.input.dispatchEvent(new Event("input", { bubbles: true }))
    this.input.dispatchEvent(new Event("change", { bubbles: true }))
    if (close) this.closeAndFocus()
  }

  position() {
    const anchor = this.triggerTarget.getBoundingClientRect()
    const panel = this.panelTarget
    const width = Math.min(320, window.innerWidth - 16)
    const height = panel.scrollHeight
    const top = window.innerHeight - anchor.bottom < height && anchor.top > window.innerHeight - anchor.bottom
      ? Math.max(8, anchor.top - height - 8) : anchor.bottom + 8
    Object.assign(panel.style, { width: `${width}px`, left: `${Math.max(8, Math.min(anchor.left, window.innerWidth - width - 8))}px`, top: `${top}px`, maxHeight: `${Math.max(100, window.innerHeight - top - 8)}px` })
  }

  outside(event) { if (!this.element.contains(event.target)) this.close() }

  escape(event) {
    if (this.panelTarget.hidden) return
    event.preventDefault()
    this.closeAndFocus()
  }

  closeAndFocus() { this.close(); this.triggerTarget.focus() }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }
}
