import { Controller } from "@hotwired/stimulus"

// Displays the server-provided SweetAlert2 message once after navigation.
// Dialog presentation is opt-in; other notices keep their shared styling.
export default class extends Controller {
    static values = {
        message: String,
        title: String,
        confirmLabel: String,
        presentation: String,
        icon: { type: String, default: "success" },
        mode: { type: String, default: "toast" },
        persistent: { type: Boolean, default: false },
        closeLabel: { type: String, default: "Close" },
        focusSelector: String
    }

    connect() {
        if (!this.messageValue || !window.Swal) return

        const modal = this.modeValue === "modal"
        const categoryWarning = modal && this.presentationValue === "category-in-use"
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
            titleText: this.titleValue || this.messageValue,
            ...(this.titleValue ? { text: this.messageValue } : {}),
            ...(this.confirmLabelValue ? { confirmButtonText: this.confirmLabelValue } : {}),
            ...(categoryWarning ? {
                customClass: { popup: "delta-category-in-use" },
                buttonsStyling: false,
                heightAuto: false,
                focusConfirm: true
            } : {}),
            didClose: () => {
                if (focusTarget?.isConnected) focusTarget.focus()
            }
        })

        // Prevent the same notification from replaying after Turbo navigation.
        this.element.remove()
    }
}
