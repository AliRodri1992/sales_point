import { Controller } from "@hotwired/stimulus"

// Progressive enhancement: the native select remains the submitted form control.
export default class extends Controller {
  connect() {
    this.select = this.element.querySelector("select")
    if (!this.select) return

    this.element.dataset.deltaSelectReady = "true"
    this.select.classList.add("sr-only")
    this.select.tabIndex = -1

    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.className = "flex min-h-12 w-full items-center justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50/60 px-4 py-3 text-left text-sm text-slate-800 transition hover:border-emerald-300 focus:outline-none focus:ring-4 focus:ring-emerald-100"
    this.button.setAttribute("aria-haspopup", "listbox")
    this.button.setAttribute("aria-expanded", "false")
    this.button.setAttribute("aria-label", this.select.labels?.[0]?.textContent?.trim() || this.select.name)
    this.label = document.createElement("span")
    this.label.className = "min-w-0 truncate"
    const chevron = document.createElement("span")
    chevron.className = "shrink-0 text-emerald-700"
    chevron.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>'
    this.button.append(this.label, chevron)

    this.menu = document.createElement("div")
    this.menu.className = "absolute left-0 right-0 top-full z-50 mt-2 max-h-64 overflow-y-auto rounded-xl border border-slate-200 bg-white p-1.5 shadow-xl"
    this.menu.hidden = true
    this.menu.setAttribute("role", "listbox")
    this.menu.id = `delta-options-${this.select.id}`
    this.button.setAttribute("aria-controls", this.menu.id)
    this.element.append(this.button, this.menu)

    this.onButtonClick = () => this.toggle()
    this.onDocumentClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.onKeyDown = (event) => {
      if (event.key === "Escape") {
        this.close()
        this.button.focus()
      } else if (event.key === "ArrowDown" && event.target === this.button) {
        event.preventDefault()
        this.open()
        this.menu.querySelector("[role='option']:not([disabled])")?.focus()
      }
    }
    this.onChange = () => this.refresh()
    this.button.addEventListener("click", this.onButtonClick)
    this.element.addEventListener("keydown", this.onKeyDown)
    this.select.addEventListener("change", this.onChange)
    document.addEventListener("click", this.onDocumentClick)
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    this.button?.removeEventListener("click", this.onButtonClick)
    this.element.removeEventListener("keydown", this.onKeyDown)
    this.select?.removeEventListener("change", this.onChange)
    this.button?.remove()
    this.menu?.remove()
    this.select?.classList.remove("sr-only")
    if (this.select) this.select.tabIndex = 0
    delete this.element.dataset.deltaSelectReady
  }

  refresh() {
    this.label.replaceChildren(this.optionContent(this.select.selectedOptions[0]))
    this.menu.replaceChildren()
    const options = [...this.select.options]
    options.forEach((option, index) => {
      const item = document.createElement("button")
      item.type = "button"
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", String(option.selected))
      item.disabled = option.disabled
      item.className = `flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-left text-sm transition hover:bg-emerald-50 focus:bg-emerald-50 focus:outline-none ${option.selected ? "bg-emerald-50 font-semibold text-emerald-800" : "text-slate-700"}`
      item.append(this.optionContent(option))
      if (option.selected) {
        const check = document.createElement("span")
        check.className = "ml-2 text-emerald-600"
        check.textContent = "✓"
        item.append(check)
      }
      item.addEventListener("click", () => this.choose(index))
      item.addEventListener("keydown", (event) => {
        const items = [...this.menu.querySelectorAll("[role='option']:not([disabled])")]
        const current = items.indexOf(item)
        if (event.key === "ArrowDown" || event.key === "ArrowUp") {
          event.preventDefault()
          items[(current + (event.key === "ArrowDown" ? 1 : -1) + items.length) % items.length]?.focus()
        } else if (event.key === "Home" || event.key === "End") {
          event.preventDefault()
          items[event.key === "Home" ? 0 : items.length - 1]?.focus()
        }
      })
      this.menu.append(item)
    })
  }

  optionContent(option) {
    const content = document.createElement("span")
    content.className = "flex min-w-0 items-center gap-2.5"

    const countryCode = this.element.dataset.countryFlags === "true" ? option?.dataset.countryCode : null
    if (countryCode && /^[A-Z]{2}$/.test(countryCode)) {
      const flag = document.createElement("img")
      flag.src = `https://flagcdn.com/${countryCode.toLowerCase()}.svg`
      flag.alt = ""
      flag.setAttribute("aria-hidden", "true")
      flag.loading = "lazy"
      flag.width = 22
      flag.height = 16
      flag.className = "h-4 w-[22px] shrink-0 rounded-sm object-cover"
      content.append(flag)
    }

    const name = document.createElement("span")
    name.className = "truncate"
    name.textContent = option?.textContent?.trim() || ""
    content.append(name)
    return content
  }

  choose(index) {
    this.select.selectedIndex = index
    this.select.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
    this.button.focus()
  }

  toggle() {
    if (this.menu.hidden) this.open()
    else this.close()
  }

  open() {
    this.menu.hidden = false
    this.button.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menu.hidden = true
    this.button.setAttribute("aria-expanded", "false")
  }
}
