import { Controller } from "@hotwired/stimulus"

// Displays the server-provided SweetAlert2 message once after navigation.
// Authentication notices may use a centered dialog; other notices remain toasts.
export default class extends Controller {
    static values = {
        message: String,
        icon: { type: String, default: "success" },
        mode: { type: String, default: "toast" },
        persistent: { type: Boolean, default: false },
        closeLabel: { type: String, default: "Close" },
        focusSelector: String
    }

    connect() {
        if (!this.messageValue || !window.Swal) return

        const modal = this.modeValue === "modal"
        const focusTarget = this.focusSelectorValue ? document.querySelector(this.focusSelectorValue) : null
        focusTarget?.focus()
        window.Swal.fire({
            toast: !modal,
            icon: this.iconValue,
            position: modal ? "center" : "top-end",
            timer: modal || this.persistentValue ? undefined : 2600,
            showConfirmButton: modal,
            showCloseButton: this.persistentValue,
            closeButtonAriaLabel: this.closeLabelValue,
            timerProgressBar: !modal && !this.persistentValue,
            title: this.messageValue,
            didClose: () => {
                if (focusTarget?.isConnected) focusTarget.focus()
            }
        })

        // Prevent the same notification from replaying after Turbo navigation.
        this.element.remove()
    }
}
