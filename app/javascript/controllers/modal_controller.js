import { Controller } from "@hotwired/stimulus"

// Reusable Turbo Frame modal. The element is the <turbo-frame id="..."> that
// acts as the fixed backdrop overlay. Content is swapped into the frame by Turbo
// (links marked with data-turbo-frame), which fires turbo:frame-load.
//
// Hidden by default (the frame carries the `hidden` class); becomes a flex,
// centered overlay when content is loaded, and back to hidden when the frame is
// emptied (e.g. after a successful create/update via Turbo Stream).
export default class extends Controller {
    static targets = ["panel"]

    connect() {
        this.isOpen = false

        this.observer = new MutationObserver(() => {
            if (this.isOpen && this.element.innerHTML.trim() === "") {
                this.hide()
            }
        })
        this.observer.observe(this.element, {childList: true, subtree: true})
    }

    disconnect() {
        this.observer?.disconnect()
        if (this.isOpen) document.documentElement.classList.remove("overflow-hidden")
    }

    frameLoaded(event) {
        if (event.target.innerHTML.trim() === "") {
            this.hide()
        } else {
            this.open()
        }
    }

    open() {
        if (!this.isOpen) this.previousFocus = document.activeElement
        this.isOpen = true
        this.element.classList.remove("hidden")
        this.element.classList.add("flex")
        this.element.setAttribute("aria-hidden", "false")
        document.documentElement.classList.add("overflow-hidden")
        this.focusPanel()
    }

    hide() {
        this.isOpen = false
        this.element.classList.add("hidden")
        this.element.classList.remove("flex")
        this.element.setAttribute("aria-hidden", "true")
        this.element.innerHTML = ""
        document.documentElement.classList.remove("overflow-hidden")
        if (this.previousFocus?.isConnected) this.previousFocus.focus()
        else document.querySelector('main a, main button')?.focus()
        this.previousFocus = null
    }

    // Triggered by keydown.esc@window, the X button, or a backdrop click.
    close(event) {
        if (!this.isOpen) return
        if (event && event.type === "click" && !this.shouldClose(event)) return
        this.hide()
    }

    // Backdrop clicks only close when the click lands directly on the overlay
    // (this element) or on a control explicitly marked for dismissal.
    background(event) {
        if (!this.isOpen) return
        if (event.target === this.element || event.target.closest("[data-modal-dismiss]")) {
            this.hide()
        }
    }

    shouldClose(event) {
        return (
            event.target.closest("[data-modal-dismiss]") !== null ||
            event.target === this.element
        )
    }

    trap(event) {
        if (!this.isOpen || event.key !== "Tab" || !this.hasPanelTarget) return
        const items = [...this.panelTarget.querySelectorAll(
            'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
        )].filter((node) => node.getClientRects().length > 0 && node.getAttribute("aria-hidden") !== "true")
        if (!items.length) return
        const first = items[0]
        const last = items[items.length - 1]
        if (event.shiftKey && (document.activeElement === first || !this.panelTarget.contains(document.activeElement))) {
            event.preventDefault()
            last.focus()
        } else if (!event.shiftKey && (document.activeElement === last || !this.panelTarget.contains(document.activeElement))) {
            event.preventDefault()
            first.focus()
        }
    }

    focusPanel() {
        if (!this.hasPanelTarget) return

        const focusable =
            this.panelTarget.querySelector("[data-autofocus]") ||
            this.panelTarget.querySelector("input, select, textarea, button")

        focusable?.focus()
    }
}
