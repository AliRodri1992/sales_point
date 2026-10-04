import { Controller } from "@hotwired/stimulus"
import { openDashboardSelector } from "./selector_coordinator"

export default class extends Controller {
    static targets = ["button", "menu"]

    toggle(event) {
        event.preventDefault()

        if (this.menuTarget.classList.contains("hidden")) {
            openDashboardSelector(this.element)
            this.open()
            return
        }

        this.close()
    }

    open() {
        this.menuTarget.classList.remove("hidden")
        this.buttonTarget.setAttribute("aria-expanded", "true")
    }

    close() {
        this.menuTarget.classList.add("hidden")
        this.buttonTarget.setAttribute("aria-expanded", "false")
    }
}
