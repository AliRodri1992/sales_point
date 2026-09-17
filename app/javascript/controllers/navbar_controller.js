import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [
        "menu",
        "button",
        "iconOpen",
        "iconClose"
    ]

    connect() {
        this.open = false
    }

    toggle() {
        this.open = !this.open

        this.menuTarget.classList.toggle("hidden", !this.open)
        this.buttonTarget.setAttribute("aria-expanded", this.open)

        this.iconOpenTarget.classList.toggle("hidden", this.open)
        this.iconCloseTarget.classList.toggle("hidden", !this.open)
    }

    close() {
        this.open = false

        this.menuTarget.classList.add("hidden")
        this.buttonTarget.setAttribute("aria-expanded", "false")

        this.iconOpenTarget.classList.remove("hidden")
        this.iconCloseTarget.classList.add("hidden")
    }
}