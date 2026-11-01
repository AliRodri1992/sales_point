import { Controller } from "@hotwired/stimulus"

// A compact chip editor backed by Supplier#tags_text (comma-separated values).
export default class extends Controller {
  static targets = ["value", "input", "chips", "count", "notice", "suggestions"]
  static values = {
    limit: { type: Number, default: 20 },
    removeLabel: String,
    duplicateMessage: String,
    limitMessage: String
  }

  connect() {
    this.tags = this.parse(this.valueTarget.value).slice(0, this.limitValue)
    this.form = this.element.closest("form")
    this.onSubmit = () => this.commitInput()
    this.form?.addEventListener("submit", this.onSubmit, true)
    this.render()
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.onSubmit, true)
  }

  parse(value) {
    return value.toString().split(/[,\n\r]+/).map((tag) => tag.normalize("NFC").trim().replace(/\s+/g, " ")).filter(Boolean)
  }

  add(event) {
    event.preventDefault()
    this.commitInput()
    this.inputTarget.focus()
  }

  keydown(event) {
    if (event.isComposing) return

    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this.commitInput()
    } else if (event.key === "Backspace" && !this.inputTarget.value && this.tags.length) {
      event.preventDefault()
      this.tags.pop()
      this.noticeTarget.textContent = ""
      this.render()
    }
  }

  paste(event) {
    const text = event.clipboardData?.getData("text") || ""
    if (!/[,\n\r]/.test(text)) return

    event.preventDefault()
    this.addTags(this.inputTarget.value + text)
    this.inputTarget.value = ""
  }

  blur() {
    this.commitInput()
  }

  suggest(event) {
    event.preventDefault()
    this.addTags(event.currentTarget.dataset.tag || "")
    this.inputTarget.focus()
  }

  remove(event) {
    const index = Number(event.currentTarget.dataset.index)
    if (!Number.isInteger(index) || index < 0 || index >= this.tags.length) return

    this.tags.splice(index, 1)
    this.noticeTarget.textContent = ""
    this.render()
    this.inputTarget.focus()
  }

  commitInput() {
    const pending = this.inputTarget.value
    if (!pending.trim()) return

    this.inputTarget.value = ""
    this.addTags(pending)
  }

  addTags(raw) {
    let warning = ""
    let changed = false
    for (const tag of this.parse(raw)) {
      if (this.tags.some((existing) => existing.toLocaleLowerCase() === tag.toLocaleLowerCase())) {
        warning ||= this.duplicateMessageValue
      } else if (this.tags.length >= this.limitValue) {
        warning = this.limitMessageValue
        break
      } else {
        this.tags.push(tag)
        changed = true
      }
    }

    this.noticeTarget.textContent = warning
    if (changed) this.render()
  }

  render() {
    this.chipsTarget.replaceChildren(...this.tags.map((tag, index) => this.chip(tag, index)))
    this.countTarget.textContent = `${this.tags.length} / ${this.limitValue}`

    const serialized = this.tags.join(", ")
    if (this.valueTarget.value !== serialized) {
      this.valueTarget.value = serialized
      this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    if (this.hasSuggestionsTarget) {
      const buttons = [...this.suggestionsTarget.querySelectorAll("button[data-tag]")]
      buttons.forEach((button) => {
        button.hidden = this.tags.some((tag) => tag.toLocaleLowerCase() === button.dataset.tag.toLocaleLowerCase())
      })
      this.suggestionsTarget.hidden = buttons.every((button) => button.hidden)
    }
  }

  chip(tag, index) {
    const chip = document.createElement("span")
    chip.className = "inline-flex max-w-full items-center gap-1.5 rounded-lg border border-emerald-200 bg-emerald-50 px-2.5 py-1.5 text-xs font-semibold text-emerald-800"

    const label = document.createElement("span")
    label.className = "min-w-0 break-all"
    label.textContent = tag

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "inline-flex size-5 shrink-0 items-center justify-center rounded-md text-emerald-600 transition hover:bg-emerald-200 hover:text-emerald-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
    remove.setAttribute("aria-label", this.removeLabelValue.replace("%{tag}", tag))
    remove.dataset.index = index
    remove.dataset.action = "supplier-tags#remove"

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    svg.setAttribute("viewBox", "0 0 24 24")
    svg.setAttribute("fill", "none")
    svg.setAttribute("stroke", "currentColor")
    svg.setAttribute("stroke-width", "2")
    svg.setAttribute("stroke-linecap", "round")
    svg.setAttribute("aria-hidden", "true")
    svg.setAttribute("class", "size-3.5")

    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("d", "M18 6 6 18M6 6l12 12")
    svg.append(path)
    remove.append(svg)
    chip.append(label, remove)
    return chip
  }
}
