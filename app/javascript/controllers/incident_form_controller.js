import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["screens", "catalog", "picker", "count", "gallery", "tile", "error", "operation"]
  static values = { failure: String, remove: String }

  connect() {
    this.files = []
    this.urls = []
    this.catalog = JSON.parse(this.catalogTarget.textContent)
    this.refreshScreens()
    this.refreshOperation()
  }

  disconnect() {
    this.urls.forEach(url => URL.revokeObjectURL(url))
  }

  moduleChanged(event) {
    if (event.target.name === "incident[affected_screen]") this.refreshOperation()
    if (event.target.name !== "incident[affected_module]") return
    const screen = this.screensTarget.querySelector("input")
    screen.value = ""
    screen.dispatchEvent(new Event("change", { bubbles: true }))
    this.refreshScreens()
  }

  refreshScreens() {
    const key = this.element.elements.namedItem("incident[affected_module]").value
    const allowed = this.catalog[key] || []
    this.screensTarget.querySelectorAll("[data-option-value]").forEach(option => {
      option.hidden = !allowed.includes(option.dataset.optionValue)
      option.disabled = option.hidden
    })
  }

  refreshOperation() {
    const field = this.element.elements.namedItem("incident[operation_reference]")
    const screen = this.element.elements.namedItem("incident[affected_screen]").value
    const mod = this.element.elements.namedItem("incident[affected_module]").value
    const hide = screen === "new" && ["system_roles", "admin/products", "admin/users"].includes(mod)
    this.operationTarget.hidden = hide
    field.disabled = hide
    const labels = JSON.parse(this.operationTarget.dataset.labels)
    field.placeholder = labels[mod] || labels.default
    const example = this.element.querySelector("[data-incident-example]")
    if (example) example.textContent = example.dataset[mod === "system_roles" ? "role" : "general"]
  }

  pick() { this.pickerTarget.click() }

  add() {
    this.files.push(...this.pickerTarget.files)
    this.pickerTarget.value = ""
    this.renderFiles()
  }

  renderFiles() {
    this.urls.forEach(url => URL.revokeObjectURL(url))
    this.urls = []
    this.galleryTarget.replaceChildren()
    this.countTarget.textContent = this.files.length
    this.files.forEach((file, index) => {
      const tile = this.tileTarget.content.firstElementChild.cloneNode(true)
      const preview = tile.querySelector(".incident-preview")
      if (["image/png", "image/jpeg", "image/webp"].includes(file.type)) {
        const image = new Image()
        image.alt = ""
        image.src = URL.createObjectURL(file)
        this.urls.push(image.src)
        preview.append(image)
      } else {
        const ext = file.name.toLowerCase().split(".").pop()
        const kind = { xls: "xlsx", doc: "docx" }[ext] || ext
        const template = Array.from(this.element.querySelectorAll("template[data-kind]")).find(el => el.dataset.kind === kind)
        if (template) preview.append(template.content.cloneNode(true))
      }
      tile.querySelector("small").textContent = file.name
      tile.title = file.name
      const button = tile.querySelector("button")
      button.setAttribute("aria-label", this.removeValue + " " + file.name)
      button.onclick = () => { this.files.splice(index, 1); this.renderFiles() }
      this.galleryTarget.append(tile)
    })
  }

  async submit(event) {
    event.preventDefault()
    if (this.sending) return
    this.sending = true
    const button = this.element.querySelector("[type=submit]")
    button.disabled = true
    const body = new FormData(this.element)
    body.delete(this.pickerTarget.name)
    this.files.forEach(file => body.append(this.pickerTarget.name, file))
    try {
      const response = await fetch(this.element.action, { method: "POST", body, headers: { Accept: "application/json" } })
      const data = await response.json()
      if (response.ok && data.url) { window.location.assign(data.url); return }
      this.errorTarget.textContent = (data.errors || [this.failureValue]).join(" · ")
    } catch {
      this.errorTarget.textContent = this.failureValue
    } finally {
      this.sending = false
      button.disabled = false
    }
    this.errorTarget.focus()
  }
}
