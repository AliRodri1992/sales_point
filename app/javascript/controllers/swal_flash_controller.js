import { Controller } from "@hotwired/stimulus"

// Displays the server-provided SweetAlert2 message once after navigation.
// Authentication notices may use a centered dialog; other notices remain toasts.
export default class extends Controller {
    static values = {
        message: String,
        icon: { type: String, default: "success" },
        mode: { type: String, default: "toast" }
    }

    connect() {
        if (!this.messageValue || !window.Swal) return

        const modal = this.modeValue === "modal"
        window.Swal.fire({
            toast: !modal,
            icon: this.iconValue,
            position: modal ? "center" : "top-end",
            timer: modal ? undefined : 2600,
            showConfirmButton: modal,
            confirmButtonColor: "#047857",
            timerProgressBar: !modal,
            title: this.messageValue
        })

        // Prevent the same notification from replaying after Turbo navigation.
        this.element.remove()
    }
}
