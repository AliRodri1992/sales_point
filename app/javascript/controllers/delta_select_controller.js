import { Controller } from "@hotwired/stimulus"

let uniqueSelectId = 0

// Progressive enhancement: the native select remains the submitted form control.
export default class extends Controller {
  connect() {
    // Turbo/Stimulus may temporarily disconnect and reconnect an unchanged
    // form element. Preserve an open dropdown across that lifecycle event.
    const restoreOpen = this.element.dataset.deltaSelectRestoreOpen === "true"
    this.select = this.element.querySelector("select")
    if (!this.select) return

    this.element.querySelectorAll("[data-delta-select-generated]").forEach((node) => node.remove())
    this.element.dataset.deltaSelectReady = "true"
    this.select.classList.add("delta-select-native")
    this.oldTabIndex = this.select.getAttribute("tabindex")
    this.select.tabIndex = -1

    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.dataset.deltaSelectGenerated = "true"
    this.button.className = "flex min-h-11 w-full items-center justify-between gap-3 rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-left text-sm text-slate-800 transition hover:border-emerald-400 focus:outline-none focus:ring-4 focus:ring-emerald-100"
    this.button.setAttribute("aria-haspopup", "listbox")
    this.button.setAttribute("aria-expanded", "false")
    this.button.setAttribute("aria-label", this.select.getAttribute("aria-label") || this.select.labels?.[0]?.textContent?.trim() || this.select.name)
    this.label = document.createElement("span")
    this.label.className = "min-w-0 truncate"
    const chevron = document.createElement("span")
    chevron.className = "shrink-0 text-emerald-700"
    chevron.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>'
    this.button.append(this.label, chevron)

    this.menu = document.createElement("div")
    this.menu.className = "absolute left-0 right-0 top-full z-50 mt-2 max-h-64 overflow-y-auto overflow-x-hidden rounded-xl border border-slate-200 bg-white p-0 shadow-xl"
    this.menu.hidden = true
    this.menu.dataset.deltaSelectGenerated = "true"
    this.searchable = this.element.dataset.countryFlags === "true" || this.element.dataset.searchable === "true"
    if (this.searchable) {
      const searchWrapper = document.createElement("div")
      searchWrapper.className = "sticky top-0 z-10 border-b border-slate-100 bg-white px-3 py-2.5"
      this.searchInput = document.createElement("input")
      this.searchInput.type = "search"
      this.searchInput.autocomplete = "off"
      this.searchInput.placeholder = this.element.dataset.searchPlaceholder || "Buscar..."
      this.searchInput.setAttribute("aria-label", this.searchInput.placeholder)
      this.searchInput.className = "block min-h-10 w-full rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-800 outline-none placeholder:text-slate-400 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
      searchWrapper.append(this.searchInput)
      this.menu.append(searchWrapper)
      this.optionsContainer = document.createElement("div")
      this.optionsContainer.className = "w-full"
      this.menu.append(this.optionsContainer)
      this.onSearchInput = () => this.filterOptions()
      this.searchInput.addEventListener("input", this.onSearchInput)
    } else {
      this.optionsContainer = this.menu
    }
    this.menu.setAttribute("role", "listbox")
    this.menu.id = "delta-options-" + (this.select.id || "dynamic-" + ++uniqueSelectId)
    this.button.setAttribute("aria-controls", this.menu.id)
    this.element.append(this.button, this.menu)

    // Activate on pointerdown, before the browser changes focus. Some forms
    // update their DOM between pointerdown and click, which loses the click.
    // Native keyboard/assistive activation generates click with detail === 0.
    this.onButtonPointerDown = (event) => {
      if (event.button !== 0) return
      event.preventDefault()
      event.stopPropagation()
      this.toggle()
      if (!this.searchable) this.button.focus()
    }
    this.onButtonClick = (event) => {
      event.stopPropagation()
      if (event.detail === 0) this.toggle()
    }
    this.onOutsidePointerDown = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.onKeyDown = (event) => {
      if (event.key === "Escape") {
        this.close()
        this.button.focus()
      } else if (event.key === "ArrowDown" && event.target === this.button) {
        event.preventDefault()
        this.open()
        this.optionsContainer.querySelector("[role='option']:not([disabled]):not([hidden])")?.focus()
      }
    }
    this.onChange = () => this.refresh()
    this.onReposition = () => {
      if (!this.menu.hidden) this.positionMenu()
    }
    this.optionObserver = new MutationObserver(() => this.refresh())
    this.optionObserver.observe(this.select, { childList: true, subtree: true, characterData: true, attributes: true,
      attributeFilter: ["disabled", "selected", "label", "hidden"] })
    this.onReset = () => setTimeout(() => this.refresh(), 0)
    this.onInvalid = (event) => { event.preventDefault(); this.button.focus() }
    this.button.addEventListener("pointerdown", this.onButtonPointerDown)
    this.button.addEventListener("click", this.onButtonClick)
    this.button.disabled = this.select.disabled
    this.button.addEventListener("focus", () => this.refresh())
    this.element.addEventListener("keydown", this.onKeyDown)
    this.select.addEventListener("change", this.onChange)
    this.select.addEventListener("invalid", this.onInvalid)
    this.select.form?.addEventListener("reset", this.onReset)
    document.addEventListener("pointerdown", this.onOutsidePointerDown, true)
    this.refresh()
    if (restoreOpen) this.open()
  }

  disconnect() {
    this.element.dataset.deltaSelectRestoreOpen = String(this.menu?.hidden === false)
    document.removeEventListener("pointerdown", this.onOutsidePointerDown, true)
    this.button?.removeEventListener("pointerdown", this.onButtonPointerDown)
    this.button?.removeEventListener("click", this.onButtonClick)
    this.element.removeEventListener("keydown", this.onKeyDown)
    this.select?.removeEventListener("change", this.onChange)
    this.select?.removeEventListener("invalid", this.onInvalid)
    this.select?.form?.removeEventListener("reset", this.onReset)
    this.optionObserver?.disconnect()
    document.removeEventListener("scroll", this.onReposition, true)
    window.removeEventListener("resize", this.onReposition)
    this.searchInput?.removeEventListener("input", this.onSearchInput)
    this.button?.remove()
    this.menu?.remove()
    this.select?.classList.remove("delta-select-native")
    if (this.select) {
      if (this.oldTabIndex === null) this.select.removeAttribute("tabindex")
      else this.select.setAttribute("tabindex", this.oldTabIndex)
    }
    delete this.element.dataset.deltaSelectReady
  }

  refresh() {
    this.button.disabled = this.select.disabled
    this.button.setAttribute("aria-invalid", String(!this.select.validity.valid))
    this.label.replaceChildren(this.optionContent(this.select.selectedOptions[0]))
    this.optionsContainer.replaceChildren()
    const options = [...this.select.options]
    options.forEach((option, index) => {
      const item = document.createElement("button")
      item.type = "button"
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", String(option.selected))
      item.disabled = option.disabled
      item.dataset.searchText = `${option.textContent} ${option.dataset.countryCode || ""}`
      item.className = "delta-select-option flex min-h-11 w-full min-w-0 items-center justify-between gap-3 rounded-none px-4 py-3 text-left text-sm font-medium transition-colors focus:outline-none"
      item.append(this.optionContent(option))
      if (option.selected) {
        const check = document.createElement("span")
        check.className = "ml-2 shrink-0 font-bold text-current"
        check.textContent = "✓"
        item.append(check)
      }
      item.addEventListener("click", () => this.choose(index))
      item.addEventListener("keydown", (event) => {
        const items = [...this.optionsContainer.querySelectorAll("[role='option']:not([disabled]):not([hidden])")]
        const current = items.indexOf(item)
        if (event.key === "ArrowDown" || event.key === "ArrowUp") {
          event.preventDefault()
          items[(current + (event.key === "ArrowDown" ? 1 : -1) + items.length) % items.length]?.focus()
        } else if (event.key === "Home" || event.key === "End") {
          event.preventDefault()
          items[event.key === "Home" ? 0 : items.length - 1]?.focus()
        }
      })
      this.optionsContainer.append(item)
    })
    if (this.searchable) this.filterOptions()
  }

  normalizeSearch(value) {
    return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim()
  }

  filterOptions() {
    const query = this.normalizeSearch(this.searchInput.value)
    this.optionsContainer.querySelectorAll("[role='option']").forEach((item) => {
      item.hidden = query.length > 0 && !this.normalizeSearch(item.dataset.searchText).includes(query)
    })
  }

  optionContent(option) {
    const content = document.createElement("span")
    content.className = "flex min-w-0 items-center gap-2.5"

    const countryCode = this.element.dataset.countryFlags === "true" ? option?.dataset.countryCode : null
    if (countryCode && /^[A-Z]{2}$/.test(countryCode) && option.dataset.flagUrl) {
      const flag = document.createElement("img")
      flag.src = option.dataset.flagUrl || ""
      flag.alt = ""
      flag.setAttribute("aria-hidden", "true")
      flag.loading = "lazy"
      flag.width = 22
      flag.height = 16
      flag.className = "h-4 w-[22px] shrink-0 rounded-sm object-cover"
      content.append(flag)
    }

    const name = document.createElement("span")
    name.className = this.element.dataset.wrapOptions === "true" ? "min-w-0 break-words leading-5" : "truncate"
    name.textContent = option?.textContent?.trim() || ""
    content.append(name)
    return content
  }

  choose(index) {
    if (this.select.options[index]?.disabled) return
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
    if (this.select.disabled) return
    this.refresh()
    if (this.searchable) {
      this.searchInput.value = ""
      this.filterOptions()
    }
    this.menu.hidden = false
    this.element.dataset.deltaSelectRestoreOpen = "true"
    this.button.setAttribute("aria-expanded", "true")
    this.element.classList.add("delta-select-open")
    this.positionMenu()
    document.addEventListener("scroll", this.onReposition, true)
    window.addEventListener("resize", this.onReposition)
    this.searchInput?.focus()
  }

  positionMenu() {
    const button = this.button.getBoundingClientRect()
    const below = Math.max(0, window.innerHeight - button.bottom - 8)
    const above = Math.max(0, button.top - 8)
    const showAbove = below < 180 && above > below
    const available = showAbove ? above : below
    const maxHeight = Math.min(256, Math.max(80, available - 6))
    const height = Math.min(this.menu.scrollHeight, maxHeight)
    const top = showAbove ? button.top - height - 6 : button.bottom + 6

    Object.assign(this.menu.style, {
      position: "fixed",
      left: Math.max(4, button.left) + "px",
      top: Math.max(4, top) + "px",
      width: button.width + "px",
      maxHeight: maxHeight + "px"
    })
  }

  close() {
    document.removeEventListener("scroll", this.onReposition, true)
    window.removeEventListener("resize", this.onReposition)
    this.element.classList.remove("delta-select-open")
    this.element.dataset.deltaSelectRestoreOpen = "false"
    this.menu.hidden = true
    this.button.setAttribute("aria-expanded", "false")
  }
}
