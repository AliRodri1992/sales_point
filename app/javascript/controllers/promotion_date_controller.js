import { Controller } from "@hotwired/stimulus"

const dateAt = (year, month, day = 1) => {
  const date = new Date(0)
  date.setUTCFullYear(year, month, day)
  return date
}
const isoDay = (date) => date.toISOString().slice(0, 10)

export default class extends Controller {
  static targets = ["trigger", "panel", "month", "days"]
  static values = { today: String }

  connect() {
    this.input = this.element.querySelector('input[type="datetime-local"]')
    if (!this.input) return
    this.element.classList.add("promotion-date-enhanced")
    this.triggerTarget.hidden = false
    const label = this.input.labels?.[0]?.textContent?.trim()
    if (label) this.triggerTarget.setAttribute("aria-label", `${this.triggerTarget.dataset.label}: ${label}`)
    this.locale = document.documentElement.lang || "en"
    this.reposition = () => { if (!this.panelTarget.hidden) this.position() }
    window.addEventListener("resize", this.reposition)
    document.addEventListener("scroll", this.reposition, true)
  }

  disconnect() {
    window.removeEventListener("resize", this.reposition)
    document.removeEventListener("scroll", this.reposition, true)
    this.element.classList.remove("promotion-date-enhanced")
    this.triggerTarget.hidden = true
    this.close()
  }

  toggle() {
    if (!this.panelTarget.hidden) return this.close()
    const date = new Date(`${this.input.value.split("T")[0] || this.todayValue}T00:00:00Z`)
    this.cursor = dateAt(date.getUTCFullYear(), date.getUTCMonth())
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.draw()
    this.position()
    const selected = this.daysTarget.querySelector('[aria-pressed="true"]') || this.daysTarget.querySelector("button")
    selected?.focus()
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
      button.setAttribute("aria-pressed", String(this.input.value.split("T")[0] === value))
      if (value === this.todayValue) button.setAttribute("aria-current", "date")
      button.addEventListener("click", () => this.select(value))
      this.daysTarget.append(button)
    }
  }

  select(value) {
    // Preserve the wall-clock time and seconds in the original Rails input.
    const time = this.input.value.split("T")[1] || "00:00:00"
    this.commit(`${value}T${time}`)
  }

  today() { this.select(this.todayValue) }
  clear() { this.commit("") }

  commit(value) {
    this.input.value = value
    this.input.dispatchEvent(new Event("input", { bubbles: true }))
    this.input.dispatchEvent(new Event("change", { bubbles: true }))
    this.closeAndFocus()
  }

  position() {
    const anchor = this.triggerTarget.getBoundingClientRect()
    const panel = this.panelTarget
    const width = Math.min(320, window.innerWidth - 16)
    const height = panel.scrollHeight
    const top = window.innerHeight - anchor.bottom < height && anchor.top > window.innerHeight - anchor.bottom
      ? Math.max(8, anchor.top - height - 8) : anchor.bottom + 8
    Object.assign(panel.style, { width: `${width}px`, left: `${Math.max(8, Math.min(anchor.right - width, window.innerWidth - width - 8))}px`, top: `${top}px`, maxHeight: `${Math.max(100, window.innerHeight - top - 8)}px` })
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
